/*
 * HappnConnector.swift
 * HappnOffice
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

import OfficeKit



public actor HappnConnector : Connector, Authenticator, HTTPAuthConnector, HasTaskQueue {
	
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
		guard !(currentScope?.isSubset(of: scope) ?? false) else {
			/* The current scope contains the scope we want, we have nothing to do. */
			return
		}
		
		try await executeOnTaskQueue{
			let currentScope = await self.currentScope
			/* We check once more if the re-connection is still needed.
			 * We have checked once, before the task queue jump, but the scope might have changed during the switch to the task queue! */
			guard !(currentScope?.isSubset(of: scope) ?? false) else {
				return
			}
			
			try await self.unqueuedDisconnect()
			try await self.unqueuedConnect(Set(scope).union(currentScope ?? []))
		}
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
			/* If we have a refresh token we try to refresh the session first because it’s good practice to keep the same session instead of re-auth’ing w/ a password.
			 * Note: Currently in the happn API, refreshing a token w/ more scope than the refresh token was created with does work. It should not. */
			if let token = try? await requestToken(.refreshToken(refreshToken)) {
				return tokenInfo = token
			} else {
				/* We should check the error and abort the connection depending on it.
				 * For now (and probably forever), we do not care.
				 * We do revoke the token if the refresh failed. */
				try await unqueuedDisconnect()
			}
		}
		
		/* Either we do not have a refresh token or the refresh of the token failed.
		 * Whatever the failure reason we retry with a password grant. */
		tokenInfo = try await requestToken(.password(username: username, password: password))
	}
	
	public func unqueuedDisconnect() async throws {
		guard let tokenInfo else {return}
		
		/* Code before URLRequestOperation v2 migration was making a GET.
		 * I find it weird but have not verified if it’s correct or not. */
		let op = URLRequestDataOperation<TokenRevokeResponseBody>.forAPIRequest(url: baseURL.appendingPathComponents("connect", "oauth", "revoke-token"), headers: ["authorization": #"OAuth="\#(tokenInfo.accessToken)""#], retryProviders: [])
		do {
			_ = try await op.startAndGetResult()
			self.tokenInfo = nil
		} catch where (error as? URLRequestOperationError)?.unexpectedStatusCodeError?.actual == 410 {
			/* We consider the 410 status code to be normal (usually it will be an invalid token, which we don’t care about as we’re disconnecting). */
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
	
	private struct TokenInfo : Sendable {
		
		let scope: Set<String>
		let userID: String
		
		let accessToken: String
		let refreshToken: String
		
		let expirationDate: Date
		
	}
	
}
