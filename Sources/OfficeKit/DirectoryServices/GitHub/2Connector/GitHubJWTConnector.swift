/*
 * GitHubJWTConnector.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



public final class GitHubJWTConnector : Connector, Authenticator {
	
	public typealias ScopeType = Void
	public typealias RequestType = URLRequest
	
	public let appId: String
	public let installationId: String
	public let privateKey: SecKey
	
	public var currentScope: Void? {
		guard let auth = auth else {return nil}
		/* We let a 21 secs leeway in which we consider we’re not connected to
		 * mitigate time difference between the server and our local time. */
		guard auth.expirationDate.timeIntervalSinceNow > 21 else {return nil}
		return ()
	}
	public var token: String? {
		return auth?.token
	}
	
	public let connectorOperationQueue = SyncOperationQueue(name: "GitHubJWTConnector Connection Queue")
	
	public init(appId a: String, installationId i: String, privateKeyURL: URL) throws {
		appId = a
		installationId = i
		privateKey = try Crypto.privateKey(pemURL: privateKeyURL)
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unsafeChangeCurrentScope(changeType: ChangeScopeOperationType<Void>, handler: @escaping (Error?) -> Void) {
		switch changeType {
		case .remove, .removeAll:
			handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented (could not find doc to revoke token...)"]))
			
		case .add(_):
			/* Retrieve connection information */
			let authURL = URL(string: "https://api.github.com/installations/\(installationId)/access_tokens")!
			let jwtRequestContent: [String: Any] = [
				"iss": appId,
				"iat": Int(Date(timeIntervalSinceNow: -90).timeIntervalSince1970), "exp": Int(Date(timeIntervalSinceNow: 90).timeIntervalSince1970)
			]
			guard let jwtRequest = try? Crypto.createRS256JWT(payload: jwtRequestContent, privateKey: privateKey) else {
				handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."]))
				return
			}
			
			/* Create the URLRequest for the JWT request */
			var request = URLRequest(url: authURL)
			request.addValue("application/vnd.github.machine-man-preview+json", forHTTPHeaderField: "Accept")
			request.addValue("Bearer \(jwtRequest)", forHTTPHeaderField: "Authorization")
			request.httpMethod = "POST"
			
			/* Run the URLRequest and parse the response in the TokenResponse object */
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			decoder.keyDecodingStrategy = .convertFromSnakeCase
			let op = AuthenticatedJSONOperation<Auth>(request: request, authenticator: nil, decoder: decoder)
			op.completionBlock = {
				guard let o = op.result else {
					handler(op.finalError ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unkown error"]))
					return
				}
				
				self.auth = o
				handler(nil)
			}
			op.start()
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
	
	private struct Auth : Codable {
		
		var token: String
		var expirationDate: Date
		
		private enum CodingKeys: String, CodingKey {
			
			case token
			case expirationDate = "expiresAt"
			
		}
		
	}
	
	private func unsafeAuthenticate(request: URLRequest, handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) {
		/* Make sure we're connected. (Note: at the time of writing, it is
		 * technically impossible for isConnected to be true and auth to be nil.
		 * We could in theory bang the auth variable, but putting it in the guard
		 * is more elegant IMHO.) */
		guard isConnected, let auth = auth else {
			handler(RError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Connected..."]), nil)
			return
		}
		
		/* Add the “Authorization” header to the request */
		var request = request
		request.addValue("token \(auth.token)", forHTTPHeaderField: "Authorization")
		handler(.success(request), nil)
	}
	
}
