/*
 * GoogleJWTConnector.swift
 * officectl
 *
 * Created by François Lamboley on 31/05/2018.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import FormURLEncodedEncoding
import JWTKit
import OperationAwaiting
import TaskQueue
import URLRequestOperation



public final actor GoogleJWTConnector : Connector, Authenticator, HasTaskQueue {
	
	public typealias Scope = Set<String>
	public typealias Request = URLRequest
	public typealias Authentication = Void
	
	public let userBehalf: String?
	public let privateKey: RSAKey
	public let superuserEmail: String
	
	public var currentScope: Scope? {
		guard let auth = auth else {return nil}
		/* We let a 21 secs leeway in which we consider we’re not connected to mitigate the potential time difference between the server and our local time. */
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
		privateKey = try RSAKey.private(pem: Data(superuserCreds.privateKey.utf8))
	}
	
	public init(from connector: GoogleJWTConnector, userBehalf u: String?) {
		userBehalf = u
		privateKey = connector.privateKey
		superuserEmail = connector.superuserEmail
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(scope: Set<String>, auth _: Void) async throws -> Set<String> {
		try await unqueuedDisconnect()
		
		let authURL = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
		let requestBody = TokenRequestBody(
			grantType: "urn:ietf:params:oauth:grant-type:jwt-bearer",
			assertion: .init(
				iss: .init(value: superuserEmail), scope: scope.joined(separator: " "),
				aud: .init(value: authURL.absoluteString), iat: .init(value: Date()), exp: .init(value: Date() + 30),
				sub: userBehalf
			),
			assertionSigner: JWTSigner.rs256(key: privateKey)
		)
		
		let op = try URLRequestDataOperation<TokenResponseBody>.forAPIRequest(url: authURL, httpBody: requestBody, bodyEncoder: FormURLEncodedEncoder(), retryProviders: [])
		let res = try await op.startAndGetResult().result
		guard res.tokenType.lowercased() == "bearer" else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected token type \(res.tokenType)"])
		}
		
		let a = Auth(token: res.accessToken, expirationDate: Date(timeIntervalSinceNow: TimeInterval(res.expiresIn)), scope: scope)
		auth = a
		return a.scope
		
		/* ***** STRUCTS ***** */
		
		struct TokenRequestBody : Encodable {
			
			struct Assertion : JWTPayload {
				var iss: IssuerClaim
				var scope: String
				var aud: AudienceClaim
				var iat: IssuedAtClaim
				var exp: ExpirationClaim
				var sub: String?
				func verify(using signer: JWTSigner) throws {
					/* We do not care, we won’t verify it, the server will. */
				}
			}
			
			var grantType: String
			var assertion: Assertion
			var assertionSigner: JWTSigner
			
			func encode(to encoder: Encoder) throws {
				var container = encoder.container(keyedBy: CodingKeys.self)
				try container.encode(grantType, forKey: .grantType)
				try container.encode(assertionSigner.sign(assertion), forKey: .assertion)
			}
			
			private enum CodingKeys : String, CodingKey {
				case grantType = "grant_type", assertion
			}
			
		}
		
		struct TokenResponseBody : Decodable {
			
			let tokenType: String
			let accessToken: String
			let expiresIn: Int
			
			private enum CodingKeys : String, CodingKey {
				case tokenType = "token_type", accessToken = "access_token", expiresIn = "expires_in"
			}
			
		}
	}
	
	public func unqueuedDisconnect() async throws {
		guard let auth = auth else {return}
		
		let op = try URLRequestDataOperation<RevokeResponseBody>.forAPIRequest(url: URL(string: "https://accounts.google.com/o/oauth2/revoke")!, urlParameters: RevokeRequestQuery(token: auth.token), retryProviders: [])
		do {
			_ = try await op.startAndGetResult()
			self.auth = nil
		} catch where (error as? URLRequestOperationError)?.unexpectedStatusCodeError?.actual == 400 {
			/* We consider the 400 status code to be normal (usually it will be an invalid token, which we don’t care about as we’re disconnecting). */
		}
		
		/* ***** STRUCTS ***** */
		
		struct RevokeRequestQuery : Encodable {
			let token: String
		}
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
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Connected..."])
		}
		
		/* Add the “Authorization” header to the request */
		var request = request
		request.addValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
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
