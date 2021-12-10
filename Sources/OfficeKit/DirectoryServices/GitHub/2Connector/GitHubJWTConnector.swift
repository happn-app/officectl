/*
 * GitHubJWTConnector.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import JWTKit
import URLRequestOperation



public final class GitHubJWTConnector : Connector, Authenticator {
	
	public typealias ScopeType = Void
	public typealias RequestType = URLRequest
	
	public let appId: String
	public let installationId: String
	public let privateKey: RSAKey
	
	public var currentScope: Void? {
		guard let auth = auth else {return nil}
		/* We let a 21 secs leeway in which we consider we’re not connected to mitigate time difference between the server and our local time. */
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
		privateKey = try RSAKey.private(pem: Data(contentsOf: privateKeyURL))
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unsafeChangeCurrentScope(changeType: ChangeScopeOperationType<Void>, handler: @escaping (Error?) -> Void) {
		Task{await handler(Result{
			switch changeType {
				case .remove, .removeAll:
					throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented (could not find doc to revoke token...)"])
					
				case .add:
					struct GitHubJWTPayload : JWTPayload {
						var iss: IssuerClaim
						var iat: IssuedAtClaim
						var exp: ExpirationClaim
						func verify(using signer: JWTSigner) throws {
							/* We do not care, we won’t verify it, the server will. */
						}
					}
					let jwtPayload = GitHubJWTPayload(iss: .init(value: appId), iat: .init(value: Date()), exp: .init(value: Date() + 30))
					let jwtToken = try JWTSigner.rs256(key: privateKey).sign(jwtPayload)
					
					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .iso8601
					decoder.keyDecodingStrategy = .convertFromSnakeCase
					let op = URLRequestDataOperation<Auth>.forAPIRequest(
						baseURL: URL(string: "https://api.github.com/app/installations/\(installationId)/access_tokens")!, method: "POST",
						headers: ["authorization": "Bearer \(jwtToken)"],
						decoders: [decoder], retryProviders: []
					)
					auth = try await op.startAndGetResult().result
			}
		}.failureValue)}
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
		/* Make sure we're connected.
		 * (Note: at the time of writing, it is technically impossible for isConnected to be true and auth to be nil.
		 *  We could in theory bang the auth variable, but putting it in the guard is more elegant IMHO.) */
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
