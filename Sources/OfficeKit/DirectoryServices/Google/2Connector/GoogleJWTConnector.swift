/*
 * GoogleJWTConnector.swift
 * officectl
 *
 * Created by François Lamboley on 31/05/2018.
 */

import Foundation

import URLRequestOperation



public final class GoogleJWTConnector : Connector, Authenticator {
	
	public typealias ScopeType = Set<String>
	public typealias RequestType = URLRequest
	
	public let userBehalf: String?
	public let privateKey: SecKey
	public let superuserEmail: String
	
	public var currentScope: ScopeType? {
		guard let auth = auth else {return nil}
		/* We let a 21 secs leeway in which we consider we’re not connected to
		 * mitigate time difference between the server and our local time. */
		guard auth.expirationDate.timeIntervalSinceNow > 21 else {return nil}
		return auth.scope
	}
	public var token: String? {
		return auth?.token
	}
	public var expirationDate: Date? {
		return auth?.expirationDate
	}
	
	public let connectorOperationQueue = SyncOperationQueue(name: "GoogleJWTConnector Connection Queue")
	
	public init(jsonCredentialsURL: URL, userBehalf u: String?) throws {
		/* Decode JSON credentials */
		let jsonDecoder = JSONDecoder()
		jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
		let superuserCreds = try jsonDecoder.decode(CredentialsFile.self, from: Data(contentsOf: jsonCredentialsURL))
		
		/* We expect to have a service account */
		guard superuserCreds.type == "service_account" else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid service account: the superuser credentials does not have a \"service_account\" type."])
		}
		
		userBehalf = u
		superuserEmail = superuserCreds.clientEmail
		privateKey = try Crypto.privateKey(pemData: Data(superuserCreds.privateKey.utf8))
	}
	
	public init(from connector: GoogleJWTConnector, userBehalf u: String?) {
		userBehalf = u
		privateKey = connector.privateKey
		superuserEmail = connector.superuserEmail
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
			
			self.unsafeConnect(scope: scope, handler: handler)
		}
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func authenticate(request: RequestType, handler: @escaping (Result<RequestType, Error>, Any?) -> Void) {
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
	
	private struct Auth : Codable {
		
		var token: String
		var expirationDate: Date
		
		var scope: Set<String>
		
	}
	
	private struct CredentialsFile : Decodable {
		
		let type: String
		let projectId: String
		let privateKeyId: String
		let privateKey: String
		let clientEmail: String
		let clientId: String
		let authUri: URL
		let tokenUri: URL
		let authProviderX509CertUrl: URL
		let clientX509CertUrl: URL
		
	}
	
	private func unsafeConnect(scope: ScopeType, handler: @escaping (Error?) -> Void) {
		/* Retrieve connection information */
		let authURL = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
		var jwtRequestContent: [String: Any] = [
			"iss": superuserEmail,
			"scope": scope.joined(separator: " "), "aud": authURL.absoluteString,
			"iat": Int(Date().timeIntervalSince1970), "exp": Int(Date(timeIntervalSinceNow: 30).timeIntervalSince1970)
		]
		if let subemail = userBehalf {jwtRequestContent["sub"] = subemail}
		guard let jwtRequest = try? Crypto.createRS256JWT(payload: jwtRequestContent, privateKey: privateKey) else {
			handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."]))
			return
		}
		
		/* Create the URLRequest for the JWT request */
		var request = URLRequest(url: authURL)
		var components = URLComponents()
		components.queryItems = [
			URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:jwt-bearer"),
			URLQueryItem(name: "assertion", value: jwtRequest)
		]
		request.httpBody = components.percentEncodedQuery?.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "+").inverted)?.data(using: .utf8)
		request.httpMethod = "POST"
		
		/* Run the URLRequest and parse the response in the TokenResponse object */
		let op = AuthenticatedJSONOperation<TokenResponse>(request: request, authenticator: nil)
		op.completionBlock = {
			guard let o = op.result.successValue else {
				handler(op.finalError ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unkown error"]))
				return
			}
			
			guard o.tokenType == "Bearer" else {
				handler(op.finalError ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected token type \(o.tokenType)"]))
				return
			}
			
			self.auth = Auth(token: o.accessToken, expirationDate: Date(timeIntervalSinceNow: TimeInterval(o.expiresIn)), scope: scope)
			handler(nil)
		}
		op.start()
		
		/* ***** TokenResponse Object ***** */
		/* This struct is used strictly for conveniently decoding the response
		 * when reading the results of the token request */
		struct TokenResponse : Decodable {
			
			let tokenType: String
			let accessToken: String
			let expiresIn: Int
			
		}
	}
	
	private func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
		guard let auth = auth else {handler(nil); return}
		
		var components = URLComponents(string: "https://accounts.google.com/o/oauth2/revoke")!
		components.queryItems = [URLQueryItem(name: "token", value: auth.token)]
		let op = URLRequestOperation(url: components.url!)
		op.completionBlock = {
			/* We consider the 400 status code to be normal (usually it will be an
			 * invalid token, which we don’t care about as we’re disconnecting). */
			let error = (op.statusCode == 400 ? nil : op.finalError)
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
		
		/* Add the “Authorization” header to the request */
		var request = request
		request.addValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
		handler(.success(request), nil)
	}
	
}
