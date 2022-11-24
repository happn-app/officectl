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
import FormURLEncodedEncoding
@preconcurrency import JWT
import OperationAwaiting
import TaskQueue
import URLRequestOperation



public actor GoogleConnector : Connector, Authenticator, HasTaskQueue {
	
	public typealias Request = URLRequest
	public typealias Authentication = Set<String>
	
	public let userBehalf: String?
	public let privateKey: RSAKey
	public let superuserEmail: String
	
	public var isConnected:  Bool         {tokenInfo != nil}
	public var accessToken:  String?      {tokenInfo?.token}
	public var currentScope: Set<String>? {tokenInfo?.scope}
	
	public init(jsonCredentialsURL: URL, userBehalf u: String?) throws {
		/* Decode JSON credentials. */
		let superuserCreds = try JSONDecoder().decode(ConnectorCredentialsFile.self, from: Data(contentsOf: jsonCredentialsURL))
		
		guard superuserCreds.type == "service_account" else {
			/* We expect to have a service account; we do not know how to handle anything else. */
			throw Err.invalidConnectorCredentials
		}
		
		userBehalf = u
		superuserEmail = superuserCreds.clientEmail
		privateKey = try RSAKey.private(pem: Data(superuserCreds.privateKey.utf8))
	}
	
	public init(from connector: GoogleConnector, userBehalf u: String?) {
		userBehalf = u
		privateKey = connector.privateKey
		superuserEmail = connector.superuserEmail
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
			 * Clients should retry requests failing for expired token reasons, but let’s be proactive and allow a useless call. */
#warning("TODO: Mechanism to avoid double-token refresh when it’s not needed (a request waiting for a response, another one is launched in parallel, both get a token expired, both will refresh, but second refresh is useless).")
			try await unqueuedConnect(tokenInfo.scope)
		}
		
		/* Make sure we're connected (_after_ potentially modifying the tokenInfo). */
		guard let tokenInfo else {
			throw Err.notConnected
		}
		
		/* Add the “Authorization” header to the request */
		var request = request
		request.addValue("Bearer \(tokenInfo.token)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	private var tokenInfo: TokenInfo?
	
	private struct TokenInfo : Sendable, Codable {
		
		var token: String
		var expirationDate: Date
		
		var scope: Set<String>
		
	}
	
}
