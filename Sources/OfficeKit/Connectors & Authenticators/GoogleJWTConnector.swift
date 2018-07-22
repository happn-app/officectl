/*
 * GoogleJWTConnector.swift
 * officectl
 *
 * Created by François Lamboley on 31/05/2018.
 */

import Foundation
#if canImport(Security)
	import Security
#endif

import AsyncOperationResult
import URLRequestOperation



public class GoogleJWTConnector : Connector, Authenticator {
	
	public typealias ScopeType = Set<String>
	public typealias RequestType = URLRequest
	
	public let userBehalf: String?
	public let privateKey: SecKey
	public let superuserEmail: String
	
	public var currentScope: ScopeType? {
		return auth?.scope
	}
	public var token: String? {
		return auth?.token
	}
	public var expirationDate: Date? {
		return auth?.expirationDate
	}
	
	public let handlerOperationQueue = HandlerOperationQueue(name: "GoogleJWTConnector")
	
	public init(jsonCredentialsURL: URL, userBehalf u: String?) throws {
		/* Decode JSON credentials */
		let jsonDecoder = JSONDecoder()
		#if !os(Linux)
			jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
		#endif
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
	
	public func unsafeConnect(scope: ScopeType, handler: @escaping (Error?) -> Void) {
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
			
			#if os(Linux)
				/* We can get rid of this when Linux supports keyDecodingStrategy */
				private enum CodingKeys : String, CodingKey {
					case tokenType = "token_type", accessToken = "access_token", expiresIn = "expires_in"
				}
			#endif
			
		}
	}
	
	public func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
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
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func authenticate(request: RequestType, handler: @escaping (AsyncOperationResult<RequestType>, Any?) -> Void) {
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
		
		#if os(Linux)
			/* We can get rid of this when Linux supports keyDecodingStrategy */
			private enum CodingKeys : String, CodingKey {
				case type, projectId = "project_id"
				case privateKeyId = "private_key_id", privateKey = "private_key"
				case clientEmail = "client_email", clientId = "client_id"
				case authUri = "auth_uri", tokenUri = "token_uri"
				case authProviderX509CertUrl = "auth_provider_x509_cert_url", clientX509CertUrl = "client_x509_cert_url"
			}
		#endif
		
	}
	
}
