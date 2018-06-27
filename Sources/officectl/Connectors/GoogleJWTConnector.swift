/*
 * GoogleJWTConnector.swift
 * officectl
 *
 * Created by François Lamboley on 31/05/2018.
 */

import Foundation

import AsyncOperationResult
import Guaka
import URLRequestOperation



class GoogleJWTConnector : Connector {
	
	typealias ScopeType = Set<String>
	typealias RequestType = URLRequest
	
	let userBehalf: String?
	let privateKey: SecKey
	let superuserEmail: String
	
	var currentScope: ScopeType? {
		return auth?.scope
	}
	var token: String? {
		return auth?.token
	}
	
	let handlerOperationQueue = HandlerOperationQueue(name: "GoogleJWTConnector")
	
	convenience init?(flags: Flags, userBehalf: String?) {
		guard let path = flags.getString(name: "google-superuser-json-creds") else {return nil}
		self.init(jsonCredentialsURL: URL(fileURLWithPath: path, isDirectory: false), userBehalf: userBehalf)
	}
	
	init?(jsonCredentialsURL: URL, userBehalf u: String?) {
		/* Decode JSON credentials */
		let jsonDecoder = JSONDecoder()
		jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
		guard let superuserCreds = try? jsonDecoder.decode(CredentialsFile.self, from: Data(contentsOf: jsonCredentialsURL)) else {
			return nil
		}
		
		/* We expect to have a service account */
		guard superuserCreds.type == "service_account" else {
			return nil
		}
		
		/* Parse the PEM key from the credentials file */
		var keys: CFArray?
		guard
			SecItemImport(Data(superuserCreds.privateKey.utf8) as CFData, nil, nil, nil, [], nil, nil, &keys) == 0,
			let key = (keys as? [SecKey])?.first
		else {
			return nil
		}
		
		userBehalf = u
		privateKey = key
		superuserEmail = superuserCreds.clientEmail
	}
	
	/* ********************************
      MARK: - Connector Implementation
	   ******************************** */
	
	func authenticate(request: RequestType, handler: @escaping (AsyncOperationResult<RequestType>, Any?) -> Void) {
		/* Make sure we're connected */
		guard let auth = auth else {
			handler(.error(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Connected..."])), nil)
			return
		}
		
		/* Add the “Authorization” header to the request */
		var request = request
		request.addValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
		handler(.success(request), nil)
	}
	
	func unsafeConnect(scope: ScopeType, handler: @escaping (Error?) -> Void) {
		/* Retrieve connection information */
		let authURL = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
		var jwtRequestContent: [String: Any] = [
			"iss": superuserEmail,
			"scope": scope.joined(separator: " "), "aud": authURL.absoluteString,
			"iat": Int(Date().timeIntervalSince1970), "exp": Int(Date(timeIntervalSinceNow: 30).timeIntervalSince1970)
		]
		if let subemail = userBehalf {jwtRequestContent["sub"] = subemail}
		guard let jwtRequest = try? JWT.encode(jwtRequest: jwtRequestContent, privateKey: privateKey) else {
			handler(NSError(domain: "JWT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."]))
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
			guard let o = op.decodedObject else {
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
	
	func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
		guard let auth = auth else {handler(nil); return}
		
		var components = URLComponents(string: "https://accounts.google.com/o/oauth2/revoke")!
		components.queryItems = [URLQueryItem(name: "token", value: auth.token)]
		let op = URLRequestOperation(url: components.url!)
		op.completionBlock = {
			if op.finalError == nil {self.auth = nil}
			handler(op.finalError)
		}
		op.start()
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
	
}
