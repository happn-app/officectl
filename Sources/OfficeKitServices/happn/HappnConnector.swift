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
	
	/* Connector types. */
	public typealias Scope = Set<String>
	public typealias Request = URLRequest
	/* Authenticator types. */
	public enum Authentication : Sendable, Hashable {
		
		case userPass(username: String, password: String)
		case refreshToken(String)
		
	}
	
	public let baseURL: URL
	
	public let clientID: String
	public let clientSecret: String
	
	public var currentScope: Set<String>? {
		guard let tokenInfo else {return nil}
		/* We let a 21 secs leeway in which we consider we’re not connected to mitigate time difference between the server and our local time. */
		guard tokenInfo.expirationDate.timeIntervalSinceNow > 21 else {return nil}
		return tokenInfo.scope
	}
	public var accessToken: String? {
		return tokenInfo?.accessToken
	}
	public var refreshToken: String? {
		return tokenInfo?.refreshToken
	}
	
	public init(baseURL url: URL, clientID id: String, clientSecret s: String) {
		baseURL = url
		
		clientID = id
		clientSecret = s
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(scope: Set<String>, auth: Authentication) async throws -> Set<String> {
		try await unqueuedDisconnect()
		
		let request = TokenRequestBody(scope: scope.joined(separator: " "), clientID: clientID, clientSecret: clientSecret, grant: auth)
		let op = try URLRequestDataOperation<TokenResponseBody>.forAPIRequest(url: baseURL.appending("connect", "oauth", "token"), httpBody: request, retryProviders: [])
		let response = try await op.startAndGetResult().result
		let ti = TokenInfo(
			scope: Set(response.scope.components(separatedBy: " ")), userID: response.userID,
			accessToken: response.accessToken, refreshToken: response.refreshToken,
			expirationDate: Date() + TimeInterval(response.expiresIn)
		)
		tokenInfo = ti
		return ti.scope
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
