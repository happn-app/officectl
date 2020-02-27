/*
 * HappnConnector.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import Crypto
import URLRequestOperation



public final class HappnConnector : Connector, Authenticator {
	
	public static let nullLoginUserId = "244"
	
	public enum AuthMode : Hashable {
		
		case userPass(username: String, password: String)
		case refreshToken(String)
		
	}
	
	public typealias ScopeType = Set<String>
	public typealias RequestType = URLRequest
	
	public let baseURL: URL
	
	public let clientId: String
	public let clientSecret: String
	
	public let authMode: AuthMode
	
	public var currentScope: Set<String>? {
		guard let auth = auth else {return nil}
		/* We let a 21 secs leeway in which we consider we’re not connected to
		 * mitigate time difference between the server and our local time. */
		guard auth.expirationDate.timeIntervalSinceNow > 21 else {return nil}
		return auth.scope
	}
	public var accessToken: String? {
		return auth?.accessToken
	}
	public var refreshToken: String? {
		return auth?.refreshToken
	}
	
	public let connectorOperationQueue = SyncOperationQueue(name: "HappnConnector Connection Queue")
	
	public convenience init(baseURL url: URL, clientId id: String, clientSecret s: String, username u: String, password p: String) {
		self.init(baseURL: url, clientId: id, clientSecret: s, authMode: .userPass(username: u, password: p))
	}
	
	public convenience init(baseURL url: URL, clientId id: String, clientSecret s: String, refreshToken t: String) {
		self.init(baseURL: url, clientId: id, clientSecret: s, authMode: .refreshToken(t))
	}
	
	public init(baseURL url: URL, clientId id: String, clientSecret s: String, authMode a: AuthMode) {
		baseURL = url
		
		clientId = id
		clientSecret = s
		
		authMode = a
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unsafeChangeCurrentScope(changeType: ChangeScopeOperationType<Set<String>>, handler: @escaping (Error?) -> Void) {
		let newScope: Set<String>?
		
		switch changeType {
		case .add(let scope):    newScope = (scope.isEmpty ? currentScope : (currentScope ?? Set()).union(scope))
		case .remove(let scope): newScope = currentScope?.subtracting(scope)
		case .removeAll:         newScope = nil
		}
		assert(newScope?.isEmpty != true) /* The scope is either nil or non-empty */
		
		unsafeDisconnect{ error in
			if let error = error {
				/* Got an error at disconnection. We stop here. */
				return handler(error)
			}
			
			guard let scope = newScope else {
				/* No new scope: simple disconnection. We stop here. */
				return handler(nil)
			}
			
			self.unsafeConnect(scope: scope, authMode: self.authMode, handler: handler)
		}
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func authenticate(request: URLRequest, handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) {
		connectorOperationQueue.addAsyncBlock{ endHandler in
			self.unsafeAuthenticate(request: request, handler: { (result, userInfo) in
				endHandler()
				handler(result, userInfo)
			})
		}
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private var auth: Auth?
	
	private struct Auth {
		
		let scope: Set<String>
		let userId: String
		
		let accessToken: String
		let refreshToken: String
		
		let expirationDate: Date
		
	}
	
	private func unsafeConnect(scope: Set<String>, authMode: AuthMode, handler: @escaping (Error?) -> Void) {
		let url = URL(string: "connect/oauth/token", relativeTo: baseURL)!
		var components = URLComponents()
		components.queryItems = [
			URLQueryItem(name: "scope", value: scope.joined(separator: " ")),
			URLQueryItem(name: "client_id", value: clientId),
			URLQueryItem(name: "client_secret", value: clientSecret)
		]
		switch authMode {
		case .userPass(username: let username, password: let password):
			components.queryItems!.append(contentsOf: [
				URLQueryItem(name: "grant_type", value: "password"),
				URLQueryItem(name: "username", value: username),
				URLQueryItem(name: "password", value: password)
			])
		case .refreshToken(let refreshToken):
			components.queryItems!.append(contentsOf: [
				URLQueryItem(name: "grant_type", value: "refresh_token"),
				URLQueryItem(name: "refresh_token", value: refreshToken)
			])
		}
		let requestData = components.percentEncodedQuery!.data(using: .utf8)!
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = requestData
		
		let op = AuthenticatedJSONOperation<TokenResponse>(request: request, authenticator: nil)
		op.completionBlock = {
			guard let o = op.result.successValue else {
				handler(op.finalError ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unkown error"]))
				return
			}
			
			self.auth = Auth(
				scope: Set(o.scope.components(separatedBy: " ")), userId: o.userId,
				accessToken: o.accessToken, refreshToken: o.refreshToken,
				expirationDate: Date(timeIntervalSinceNow: TimeInterval(o.expiresIn))
			)
			handler(nil)
		}
		op.start()
		
		/* ***** TokenResponse Object ***** */
		/* This struct is used strictly for conveniently decoding the response
		 * when reading the results of the token request */
		struct TokenResponse : Decodable {
			
			let scope: String
			let userId: String
			
			let accessToken: String
			let refreshToken: String
			
			let expiresIn: Int
			let errorCode: Int
			
		}
	}
	
	public func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
		guard let auth = auth else {handler(nil); return}
		
		var request = URLRequest(url: URL(string: "connect/oauth/revoke-token", relativeTo: baseURL)!)
		request.setValue("OAuth=\"\(auth.accessToken)\"", forHTTPHeaderField: "Authorization")
		let op = URLRequestOperation(request: request)
		op.completionBlock = {
			/* We consider the 410 status code to be normal (usually it will be an
			 * invalid token, which we don’t care about as we’re disconnecting). */
			let error = (op.statusCode == 410 ? nil : op.finalError)
			if error == nil {self.auth = nil}
			handler(error)
		}
		op.start()
	}
	
	private func unsafeAuthenticate(request: URLRequest, handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) {
		/* Make sure we're connected */
		guard let auth = auth else {
			handler(RError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Connected..."]), nil)
			return
		}
		
		var request = request
		
		/* *** Add the “Authorization” header to the request *** */
		request.setValue("OAuth=\"\(auth.accessToken)\"", forHTTPHeaderField: "Authorization")
		
		/* *** Sign the request *** */
		let queryData = request.url?.query?.data(using: .ascii)
		let queryDataLength = queryData?.count ?? 0
		let bodyDataLength = request.httpBody?.count ?? 0
		if
			let clientSecretData = clientSecret.data(using: .ascii),
			let clientIdData = clientId.data(using: .ascii),
			let pathData = request.url?.path.data(using: .ascii),
			let httpMethodData = request.httpMethod?.data(using: .ascii),
			let backslashData = "\\".data(using: .ascii),
			let semiColonData = ";".data(using: .ascii)
		{
			var key = Data(capacity: clientSecretData.count + clientIdData.count + 1)
			key.append(clientSecretData)
			key.append(backslashData)
			key.append(clientIdData)
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
			/* content is (the part in brackets is only there if the value of the
			 * field is not empty): "url_path[?url_query];http_body;http_method" */
			
			let hmac = Data(HMAC<SHA256>.authenticationCode(for: content, using: SymmetricKey(data: key)))
			request.setValue(hmac.reduce("", { $0 + String(format: "%02x", $1) }), forHTTPHeaderField: "Signature")
		}
		
		handler(.success(request), nil)
	}
	
}
