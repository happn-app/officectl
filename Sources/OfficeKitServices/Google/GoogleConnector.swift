/*
 * GoogleConnector.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2018/05/31.
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



public actor GoogleConnector : Connector, Authenticator, HTTPAuthConnector, HasTaskQueue {
	
	public typealias Request = URLRequest
	public typealias Authentication = Set<String>
	
	public let userBehalf: String?
	public let privateKey: RSAKey
	public let superuserEmail: String
	
	public var isConnected:  Bool         {tokenInfo != nil}
	public var accessToken:  String?      {tokenInfo?.token}
	public var currentScope: Set<String>? {tokenInfo?.scope}
	
	public init(jsonCredentialsURL: URL, userBehalf: String?) throws {
		/* Decode JSON credentials. */
		let superuserCreds = try JSONDecoder().decode(ConnectorCredentialsFile.self, from: Data(contentsOf: jsonCredentialsURL))
		
		guard superuserCreds.type == "service_account" else {
			/* We expect to have a service account; we do not know how to handle anything else. */
			throw Err.invalidConnectorCredentials
		}
		
		self.userBehalf = userBehalf
		self.superuserEmail = superuserCreds.clientEmail
		self.privateKey = try RSAKey.private(pem: Data(superuserCreds.privateKey.utf8))
	}
	
	public init(from connector: GoogleConnector, userBehalf: String?) {
		self.userBehalf = userBehalf
		self.privateKey = connector.privateKey
		self.superuserEmail = connector.superuserEmail
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
		
		let authURL = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
		let requestBody = TokenRequestBody(
			grantType: "urn:ietf:params:oauth:grant-type:jwt-bearer",
			assertion: .init(
				iss: .init(value: superuserEmail), scope: scope.joined(separator: " "),
				aud: .init(value: authURL.absoluteString), iat: .init(value: Date()), exp: .init(value: Date() + 30),
				sub: userBehalf.flatMap(SubjectClaim.init(value:))
			),
			assertionSigner: JWTSigner.rs256(key: privateKey)
		)
		
		let op = try URLRequestDataOperation<TokenResponseBody>.forAPIRequest(url: authURL, httpBody: requestBody, bodyEncoder: FormURLEncodedEncoder(), retryProviders: [])
		let res = try await op.startAndGetResult().result
		guard res.tokenType.lowercased() == "bearer" else {
			throw Err.unsupportedTokenType(res.tokenType)
		}
		
		tokenInfo = TokenInfo(token: res.accessToken, expirationDate: Date(timeIntervalSinceNow: TimeInterval(res.expiresIn)), scope: scope)
	}
	
	public func unqueuedDisconnect() async throws {
		guard let tokenInfo else {return}
		
		let op = try URLRequestDataOperation<TokenRevokeResponseBody>.forAPIRequest(url: URL(string: "https://accounts.google.com/o/oauth2/revoke")!, urlParameters: TokenRevokeRequestQuery(token: tokenInfo.token), retryProviders: [])
		do {
			_ = try await op.startAndGetResult()
			self.tokenInfo = nil
		} catch where (error as? URLRequestOperationError)?.unexpectedStatusCodeError?.actual == 400 {
			/* We consider the 400 status code to be normal (usually it will be an invalid token, which we don’t care about as we’re disconnecting). */
		}
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
