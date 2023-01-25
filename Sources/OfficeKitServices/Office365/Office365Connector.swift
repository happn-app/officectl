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



public actor Office365Connector : Connector, Authenticator, HasTaskQueue {
	
	public typealias Request = URLRequest
	public typealias Authentication = Set<String>
	
	public let tenantID: String
	
	public let clientID: String
	public let clientSecret: String
	
	public var isConnected:  Bool         {tokenInfo != nil}
	public var accessToken:  String?      {tokenInfo?.token}
	public var currentScope: Set<String>? {tokenInfo?.scope}
	
	public init(tenantID: String, clientID: String, clientSecret: String) throws {
		self.tenantID = tenantID
		self.clientID = clientID
		self.clientSecret = clientSecret
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
		let requestBody = TokenRequestBody(
			scope: scope.joined(separator: ","),
			grantType: "client_credentials",
			clientID: clientID,
			clientSecret: clientSecret
//			clientAssertionType: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
//			clientAssertion: .init(
//				aud: .init(value: authURL.absoluteString),
//				iss: .init(value: clientID),
//				sub: .init(value: clientID),
//				jti: UUID(),
//				nbf: .init(value: .now - 9),
//				exp: .init(value: .now + 30)
//			),
//			kid: .init(string: certifID),
//			assertionSigner: JWTSigner.rs256(key: privateKey)
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
		
//		let op = try URLRequestDataOperation<TokenRevokeResponseBody>.forAPIRequest(url: URL(string: "https://accounts.google.com/o/oauth2/revoke")!, urlParameters: TokenRevokeRequestQuery(token: tokenInfo.token), retryProviders: [])
//		do {
//			_ = try await op.startAndGetResult()
//			self.tokenInfo = nil
//		} catch where (error as? URLRequestOperationError)?.unexpectedStatusCodeError?.actual == 400 {
//			/* We consider the 400 status code to be normal (usually it will be an invalid token, which we don’t care about as we’re disconnecting). */
//		}
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
		
		/* Add the “Authorization” header to the request. */
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
