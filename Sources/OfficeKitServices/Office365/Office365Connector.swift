/*
 * Office365Connector.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import FormURLEncodedCoder
@preconcurrency import JWT
import OperationAwaiting
import TaskQueue
import URLRequestOperation

import OfficeKit



public actor Office365Connector : Connector, Authenticator, HTTPAuthConnector, HasTaskQueue {
	
	public typealias Request = URLRequest
	public typealias Authentication = Set<String>
	
	public enum Grant : Sendable {
		
		case clientSecret(String)
		case clientCertificate(x5t: String, privateKey: RSAKey)
		
	}
	
	public let tenantID: String
	
	public let clientID: String
	public let grant: Grant
	
	public var isConnected:  Bool         {tokenInfo != nil}
	public var accessToken:  String?      {tokenInfo?.token}
	public var currentScope: Set<String>? {tokenInfo?.scope}
	
	public init(tenantID: String, clientID: String, grant: Office365ServiceConfig.ConnectorSettings.Grant, workdir: URL? = nil) throws {
		switch grant {
			case let .clientSecret(secret):                       self.init(tenantID: tenantID, clientID: clientID, clientSecret: secret)
			case let .clientCertificate(x5t, privateKeyPath): try self.init(tenantID: tenantID, clientID: clientID, clientCertificateX5t: x5t, clientCertificateKeyURL: URL(fileURLWithPath: privateKeyPath, isDirectory: false, relativeTo: workdir))
		}
	}
	
	public init(tenantID: String, clientID: String, clientSecret: String) {
		self.init(tenantID: tenantID, clientID: clientID, grant: .clientSecret(clientSecret))
	}
	
	public init(tenantID: String, clientID: String, clientCertificateX5t: String, clientCertificateKeyURL: URL) throws {
		let key = try RSAKey.private(pem: Data(contentsOf: clientCertificateKeyURL))
		self.init(tenantID: tenantID, clientID: clientID, grant: .clientCertificate(x5t: clientCertificateX5t, privateKey: key))
	}
	
	public init(tenantID: String, clientID: String, grant: Grant) {
		self.tenantID = tenantID
		self.clientID = clientID
		self.grant = grant
	}
	
	public func increaseScopeIfNeeded(_ scope: String...) async throws {
		guard !(currentScope?.isSubset(of: scope) ?? false) else {
			/* The current scope contains the scope we want, we have nothing to do. */
			return
		}
		
		let scope = Set(scope).union(currentScope ?? [])
		try await executeOnTaskQueue{
			try await self.unqueuedDisconnect()
			try await self.unqueuedConnect(scope)
		}
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(_ scope: Set<String>) async throws {
		try await unqueuedDisconnect()
		
		let authURL = try URL(string: "https://login.microsoftonline.com")!.appending(tenantID, "oauth2", "v2.0", "token")
		let tokenRequestGrant: TokenRequestBody.Grant
		switch grant {
			case let .clientSecret(secret):
				tokenRequestGrant = .clientSecret(secret)
				
			case let .clientCertificate(x5t: x5t, privateKey: privateKey):
				let assertion = TokenRequestAssertion(
					aud: .init(value: authURL.absoluteString),
					iss: .init(value: clientID),
					sub: .init(value: clientID),
					jti: UUID(),
					nbf: .init(value: Date() - 9),
					exp: .init(value: Date() + 30)
				)
				tokenRequestGrant = .signedAssertion(
					/* M$ expects the x5t to be in a “x5t” field in the header instead of a “kid” field,
					 *  but the JWT framework does not allow header fields customization. */
					try JWTSigner.rs256(key: privateKey).sign(assertion, kid: .init(string: x5t)),
					type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
				)
		}
		let requestBody = TokenRequestBody(
			grantType: "client_credentials",
			clientID: clientID,
			grant: tokenRequestGrant,
			scope: scope.joined(separator: ",")
		)
		
		let op = try URLRequestDataOperation<TokenResponseBody>.forAPIRequest(url: authURL, httpBody: requestBody, bodyEncoder: FormURLEncodedEncoder(), retryProviders: [])
		let res = try await op.startAndGetResult().result
		guard res.tokenType.lowercased() == "bearer" else {
			throw Err.unsupportedTokenType(res.tokenType)
		}
		
		tokenInfo = TokenInfo(token: res.accessToken, expirationDate: Date(timeIntervalSinceNow: TimeInterval(res.expiresIn)), scope: scope)
	}
	
	public func unqueuedDisconnect() async throws {
		/* So AFAICT there are no endpoints to revoke an access token for the M$ graph API.
		 * Makes sense, it’s a JWT token.
		 * Still a bold move though… */
		tokenInfo = nil
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		if let tokenInfo, tokenInfo.expirationDate < Date() + TimeInterval(30) {
			/* If the token expires soon, we reauth it.
			 * Clients should retry requests failing for expired token reasons, but let’s be proactive and allow a useless call.
			 * We do not fail if the token refresh fails; our current token might still be valid.
			 *
			 * If the access token has _already_ expired, we do have to wait for the end of the refresh token step.
			 * If it has not, we could spawn the refresh in the background and continue on our merry way.
			 * We do not do this currently (TODO?): we wait whether the refresh was required or not.
			 *
			 * “-TimeInterval(45)”: "Rate-limiting" of the refresh of the token from request authentication to 1 per 45 seconds.
			 * This avoids refreshing the token for each requests if the access token expires less than 45s after it is created. */
			_ = try? await unqueuedRefreshToken(requestAuthDate: Date() - TimeInterval(45))
		}
		
		/* Make sure we're connected (_after_ potentially modifying the tokenInfo). */
		guard let tokenInfo else {
			throw Err.notConnected
		}
		
		/* Add the “Authorization” header to the request. */
		var request = request
		request.addValue("Bearer \(tokenInfo.token)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	/* ****************************************
	   MARK: - HTTP Auth Connector (Retry Auth)
	   **************************************** */
	
	public func refreshToken(requestAuthDate: Date?) async throws {
		try await executeOnTaskQueue{ try await self.unqueuedRefreshToken(requestAuthDate: requestAuthDate) }
	}
	
	private func unqueuedRefreshToken(requestAuthDate: Date?) async throws {
		guard let scope = tokenInfo?.scope else {
			throw Err.notConnected
		}
		guard (requestAuthDate ?? .distantFuture) > authInfoChangeDate else {
			/* The access auth has been changed _after_ the request was authenticated; we do not refresh the token (would probably be a double-refresh). */
			return
		}
		try await unqueuedConnect(scope)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	/* We only use this variable to avoid a double-refresh of the access token. */
	private var authInfoChangeDate = Date.distantPast
	private var tokenInfo: TokenInfo? {
		didSet {authInfoChangeDate = Date()}
	}
	
	private struct TokenInfo : Sendable, Codable {
		
		var token: String
		var expirationDate: Date
		
		var scope: Set<String>
		
	}
	
}
