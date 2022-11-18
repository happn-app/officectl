/*
 * HappnConnector.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/27.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import Crypto
import OperationAwaiting
import TaskQueue
import URLRequestOperation



public actor HappnConnector : Connector, Authenticator, HasTaskQueue {
	
	public typealias Request = URLRequest
	public typealias Authentication = Set<String>
	
	public let baseURL: URL
	
	public let clientID: String
	public let clientSecret: String
	
	public let username: String
	public let password: String
	
	public var isConnected:  Bool         {tokenInfo != nil}
	public var accessToken:  String?      {tokenInfo?.accessToken}
	public var refreshToken: String?      {tokenInfo?.refreshToken}
	public var currentScope: Set<String>? {tokenInfo?.scope}
	
	public init(baseURL: URL, clientID: String, clientSecret: String, username: String, password: String) {
		self.baseURL = baseURL
		
		self.clientID = clientID
		self.clientSecret = clientSecret
		
		self.username = username
		self.password = password
	}
	
	public func increaseScopeIfNeeded(_ scope: String...) async throws {
		guard currentScope?.isSubset(of: scope) ?? false else {
			/* The current scope contains the scope we want, we have nothing to do. */
			return
		}
		
		let scope = Set(scope).union(currentScope ?? [])
		try await unqueuedDisconnect()
		try await unqueuedConnect(scope)
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(_ scope: Authentication) async throws {
		let requestToken = { (grant: TokenRequestBody.Grant) async throws -> TokenInfo in
			let request = TokenRequestBody(clientID: self.clientID, clientSecret: self.clientSecret, grant: grant, scope: scope)
			let op = try URLRequestDataOperation<TokenResponseBody>.forAPIRequest(url: self.baseURL.appending("connect", "oauth", "token"), httpBody: request, retryProviders: [])
			let response = try await op.startAndGetResult().result
			return TokenInfo(
				scope: Set(response.scope.components(separatedBy: " ")), userID: response.userID,
				accessToken: response.accessToken, refreshToken: response.refreshToken,
				expirationDate: Date() + TimeInterval(response.expiresIn)
			)
		}
		
		if let refreshToken {
			/* If we have a refresh token we try to refresh the session first because it’s good practice to keep the same session instead of re-auth’ing w/ a password. */
			if let token = try? await requestToken(.refreshToken(refreshToken)) {
				return tokenInfo = token
			}
			/* We should check the error and abort the connection depending on it.
			 * For now (and probably forever), we do not care. */
		}
		
		/* Either we do not have a refresh token or the refresh of the token failed.
		 * Whatever the failure reason we retry with a password grant. */
		tokenInfo = try await requestToken(.password(username: username, password: password))
	}
	
	public func unqueuedDisconnect() async throws {
		guard let tokenInfo else {return}
		
		/* Code before URLRequestOperation v2 migration was making a GET.
		 * I find it weird but have not verified if it’s correct or not. */
		let op = URLRequestDataOperation<RevokeResponseBody>.forAPIRequest(url: baseURL.appendingPathComponents("connect", "oauth", "revoke-token"), headers: ["authorization": #"OAuth="\#(tokenInfo.accessToken)""#], retryProviders: [])
		do {
			_ = try await op.startAndGetResult()
			self.tokenInfo = nil
		} catch where ((error as? URLRequestOperationError)?.postProcessError as? URLRequestOperationError.UnexpectedStatusCode)?.actual == 410 {
			/* We consider the 410 status code to be normal (usually it will be an invalid token, which we don’t care about as we’re disconnecting). */
		}
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		/* Make sure we're connected */
		guard let tokenInfo else {
			throw Err.notConnected
		}
		
		if tokenInfo.expirationDate >= Date() - TimeInterval(30) {
			/* If the token expires soon, we reauth it.
			 * Clients should retry requests failing for expired token reasons, but let’s be proactive and allow a useless call. */
#warning("TODO: Mechanism to avoid double-token refresh when it’s not needed (a request waiting for a response, another one is launched in parallel, both get a token expired, both will refresh, but second refresh is useless).")
			try await unqueuedConnect(tokenInfo.scope)
		}
		
		var request = request
		
		/* *** Add the “Authorization” header to the request *** */
		request.setValue("OAuth=\"\(tokenInfo.accessToken)\"", forHTTPHeaderField: "Authorization")
		
		/* *** Sign the request *** */
		let queryData = request.url?.query?.data(using: .ascii)
		let queryDataLength = queryData?.count ?? 0
		let bodyDataLength = request.httpBody?.count ?? 0
		if
			let clientSecretData = clientSecret.data(using: .ascii),
			let clientIDData = clientID.data(using: .ascii),
			let pathData = request.url?.path.data(using: .ascii),
			let httpMethodData = request.httpMethod?.data(using: .ascii),
			let backslashData = "\\".data(using: .ascii),
			let semiColonData = ";".data(using: .ascii)
		{
			var key = Data(capacity: clientSecretData.count + clientIDData.count + 1)
			key.append(clientSecretData)
			key.append(backslashData)
			key.append(clientIDData)
			/* key is: "client_secret\client_id" */
			
			var content = Data(capacity: pathData.count + 1 + queryDataLength + 1 + bodyDataLength + 1 + httpMethodData.count)
			content.append(pathData)
			if let queryData = queryData, let interrogationPointData = "?".data(using: .ascii) {
				content.append(interrogationPointData)
				content.append(queryData)
			}
			content.append(semiColonData)
			if let body = request.httpBody {content.append(body)}
			content.append(semiColonData)
			content.append(httpMethodData)
			/* content is (the part in brackets is only there if the value of the field is not empty): "url_path[?url_query];http_body;http_method" */
			
			let hmac = Data(HMAC<SHA256>.authenticationCode(for: content, using: SymmetricKey(data: key)))
			request.setValue(hmac.reduce("", { $0 + String(format: "%02x", $1) }), forHTTPHeaderField: "Signature")
		}
		
		return request
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	private var tokenInfo: TokenInfo?
	
	private struct TokenInfo {
		
		let scope: Set<String>
		let userID: String
		
		let accessToken: String
		let refreshToken: String
		
		let expirationDate: Date
		
	}
	
}
