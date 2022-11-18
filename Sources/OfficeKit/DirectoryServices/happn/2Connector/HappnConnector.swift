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
import TaskQueue
import URLRequestOperation



public final actor HappnConnector : Connector, Authenticator, HasTaskQueue {
	
	public static let nullLoginUserID = "244"
	
	public enum AuthMode : Sendable, Hashable {
		
		case userPass(username: String, password: String)
		case refreshToken(String)
		
	}
	
	public typealias Request = URLRequest
	public typealias Authentication = Set<String>
	
	public let baseURL: URL
	
	public let clientID: String
	public let clientSecret: String
	
	public let authMode: AuthMode
	
	public var isConnected: Bool {
		currentScope != nil
	}
	
	public var currentScope: Set<String>? {
		guard let auth = auth else {return nil}
		/* We let a 21 secs leeway in which we consider we’re not connected to mitigate time difference between the server and our local time. */
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
	
	public init(baseURL url: URL, clientID id: String, clientSecret s: String, username u: String, password p: String) {
		self.init(baseURL: url, clientID: id, clientSecret: s, authMode: .userPass(username: u, password: p))
	}
	
	public init(baseURL url: URL, clientID id: String, clientSecret s: String, refreshToken t: String) {
		self.init(baseURL: url, clientID: id, clientSecret: s, authMode: .refreshToken(t))
	}
	
	public init(baseURL url: URL, clientID id: String, clientSecret s: String, authMode a: AuthMode) {
		baseURL = url
		
		clientID = id
		clientSecret = s
		
		authMode = a
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(_ scope: Set<String>) async throws {
		try await unqueuedDisconnect()
		
		let request = TokenRequestBody(scope: scope.joined(separator: " "), clientID: clientID, clientSecret: clientSecret, grant: authMode)
		let op = try URLRequestDataOperation<TokenResponseBody>.forAPIRequest(url: baseURL.appending("connect", "oauth", "token"), httpBody: request, retryProviders: [])
		let response = try await op.startAndGetResult().result
		auth = Auth(
			scope: Set(response.scope.components(separatedBy: " ")), userID: response.userID,
			accessToken: response.accessToken, refreshToken: response.refreshToken,
			expirationDate: Date() + TimeInterval(response.expiresIn)
		)
		
		/* ***** STRUCTS ***** */
		
		struct TokenRequestBody : Encodable {
			
			var scope: String
			var clientID: String
			var clientSecret: String?
			
			var grant: AuthMode
			
			func encode(to encoder: Encoder) throws {
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode(scope, forKey: .scope)
				try container.encode(clientID, forKey: .clientID)
				try container.encode(clientSecret, forKey: .clientSecret)
				switch grant {
					case let .userPass(username: username, password: password):
						try container.encode("password", forKey: .grantType)
						try container.encode(username, forKey: .username)
						try container.encode(password, forKey: .password)
						
					case let .refreshToken(refreshToken):
						try container.encode("refresh_token", forKey: .grantType)
						try container.encode(refreshToken, forKey: .refreshToken)
				}
			}
			
			private enum CodingKeys : String, CodingKey {
				case scope, clientID = "client_id", clientSecret = "client_secret"
				case grantType = "grant_type"
				case username, password
				case refreshToken = "refresh_token"
			}
			
		}
		
		struct TokenResponseBody : Decodable {
			
			let scope: String
			let userID: String
			
			let accessToken: String
			let refreshToken: String
			
			let expiresIn: Int
			let errorCode: Int
			
			private enum CodingKeys : String, CodingKey {
				case scope, userID = "user_id"
				case accessToken = "access_token", refreshToken = "refresh_token"
				case expiresIn = "expires_in"
				case errorCode = "error_code"
			}
			
		}
	}
	
	public func unqueuedDisconnect() async throws {
		guard let auth = auth else {return}
		
		/* Code before URLRequestOperation v2 migration was making a GET.
		 * I find it weird but have not verified if it’s correct or not. */
		let op = URLRequestDataOperation<RevokeResponseBody>.forAPIRequest(url: baseURL.appendingPathComponents("connect", "oauth", "revoke-token"), headers: ["authorization": #"OAuth="\#(auth.accessToken)""#], retryProviders: [])
		do {
			_ = try await op.startAndGetResult()
			self.auth = nil
		} catch where ((error as? URLRequestOperationError)?.postProcessError as? URLRequestOperationError.UnexpectedStatusCode)?.actual == 410 {
			/* We consider the 410 status code to be normal (usually it will be an invalid token, which we don’t care about as we’re disconnecting). */
		}
		
		/* ***** STRUCTS ***** */
		
		struct RevokeResponseBody : Decodable {
			/* I don’t know! */
		}
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		/* Make sure we're connected */
		guard let auth = auth else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Connected."])
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
	
	private var auth: Auth?
	
	private struct Auth {
		
		let scope: Set<String>
		let userID: String
		
		let accessToken: String
		let refreshToken: String
		
		let expirationDate: Date
		
	}
	
}
