/*
 * GitHubJWTConnector.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation

import AsyncOperationResult



class GitHubJWTConnector : Connector, Authenticator {
	
	typealias ScopeType = Void
	typealias RequestType = URLRequest
	
	let appId: String
	let installationId: String
	let privateKey: SecKey
	
	var currentScope: Void? {
		return (auth != nil ? () : nil)
	}
	var token: String? {
		return auth?.token
	}
	
	let handlerOperationQueue: HandlerOperationQueue = HandlerOperationQueue(name: "GitHubJWTConnector")
	
	init?(appId a: String, installationId i: String, privateKeyURL: URL) {
		/* Parse the PEM key from the credentials file */
		var keys: CFArray?
		guard
			let privateKeyData = try? Data(contentsOf: privateKeyURL),
			SecItemImport(privateKeyData as CFData, nil, nil, nil, [], nil, nil, &keys) == 0,
			let key = (keys as? [SecKey])?.first
		else {
			return nil
		}
		
		appId = a
		installationId = i
		privateKey = key
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	func authenticate(request: URLRequest, handler: @escaping (AsyncOperationResult<URLRequest>, Any?) -> Void) {
		/* Make sure we're connected */
		guard let auth = auth else {
			handler(.error(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Connected..."])), nil)
			return
		}
		
		/* Add the “Authorization” header to the request */
		var request = request
		request.addValue("token \(auth.token)", forHTTPHeaderField: "Authorization")
		handler(.success(request), nil)
	}
	
	func unsafeConnect(scope: Void, handler: @escaping (Error?) -> Void) {
		/* Retrieve connection information */
		let authURL = URL(string: "https://api.github.com/installations/\(installationId)/access_tokens")!
		let jwtRequestContent: [String: Any] = [
			"iss": appId,
			"iat": Int(Date().timeIntervalSince1970), "exp": Int(Date(timeIntervalSinceNow: 30).timeIntervalSince1970)
		]
		guard let jwtRequest = try? JWT.encode(jwtRequest: jwtRequestContent, privateKey: privateKey) else {
			handler(NSError(domain: "JWT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."]))
			return
		}
		
		/* Create the URLRequest for the JWT request */
		var request = URLRequest(url: authURL)
		request.addValue("application/vnd.github.machine-man-preview+json", forHTTPHeaderField: "Accept")
		request.addValue("Bearer \(jwtRequest)", forHTTPHeaderField: "Authorization")
		request.httpMethod = "POST"
		
		/* Run the URLRequest and parse the response in the TokenResponse object */
		let op = AuthenticatedJSONOperation<Auth>(request: request, authenticator: nil)
		op.completionBlock = {
			guard let o = op.decodedObject else {
				handler(op.finalError ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unkown error"]))
				return
			}
			
			self.auth = o
			handler(nil)
		}
		op.start()
	}
	
	func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
		handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented (could not find doc to revoke token...)"]))
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var auth: Auth?
	
	private struct Auth : Codable {
		
		var token: String
		var expirationDate: String
		
		private enum CodingKeys: String, CodingKey {
			
			case token
			case expirationDate = "expiresAt"
			
		}
		
	}
	
}
