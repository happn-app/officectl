/*
 * GitHubJWTConnector.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import JWTKit
import TaskQueue
import URLRequestOperation



public final actor GitHubJWTConnector : Connector, Authenticator, HasTaskQueue {
	
	public typealias Scope = Void
	public typealias Request = URLRequest
	public typealias Authentication = Void
	
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
	
	public func unqueuedConnect(scope _: Void, auth _: Void) async throws -> Void {
		struct GitHubJWTPayload : JWTPayload {
			var iss: IssuerClaim
			var iat: IssuedAtClaim
			var exp: ExpirationClaim
			func verify(using signer: JWTSigner) throws {
				/* We do not care, we won’t verify it, the server will. */
			}
		}
		/* GitHub does not support non-int exp or iat. */
		let roundedNow = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded())
		let jwtPayload = GitHubJWTPayload(iss: .init(value: appId), iat: .init(value: roundedNow), exp: .init(value: roundedNow + 30))
		let jwtToken = try JWTSigner.rs256(key: privateKey).sign(jwtPayload)
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let op = URLRequestDataOperation<Auth>.forAPIRequest(
			url: try URL(string: "https://api.github.com")!.appending("app", "installations", installationId, "access_tokens"),
			method: "POST", headers: ["authorization": "Bearer \(jwtToken)"],
			decoders: [decoder], retryProviders: []
		)
		auth = try await op.startAndGetResult().result
	}
	
	public func unqueuedDisconnect() async throws {
		throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented (could not find doc to revoke token...)"])
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		/* Make sure we're connected.
		 * (Note: at the time of writing, it is technically impossible for isConnected to be true and auth to be nil.
		 *  We could in theory bang the auth variable, but putting it in the guard is more elegant IMHO.) */
		guard isConnected, let auth = auth else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Connected."])
		}
		
		/* Add the “Authorization” header to the request */
		var request = request
		request.addValue("token \(auth.token)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	private var auth: Auth?
	
	private struct Auth : Codable {
		
		var token: String
		var expirationDate: Date
		
		private enum CodingKeys: String, CodingKey {
			
			case token
			case expirationDate = "expiresAt"
			
		}
		
	}
	
}
