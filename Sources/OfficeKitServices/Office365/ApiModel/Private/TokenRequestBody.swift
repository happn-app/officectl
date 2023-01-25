/*
 * TokenRequestBody.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

@preconcurrency import JWT



struct TokenRequestBody : Sendable, Encodable {
	
	struct Assertion : JWTPayload {
		var aud: AudienceClaim
		var iss: IssuerClaim
		var sub: SubjectClaim
		var jti: UUID
		var nbf: NotBeforeClaim
		var exp: ExpirationClaim
		func verify(using signer: JWTSigner) throws {
			/* We do not verify the token, the server will. */
			throw Err.unsupportedOperation
		}
	}
	
	var scope: String
	
	var grantType: String
	var clientID: String
	var clientSecret: String
//	var clientAssertionType: String
//	var clientAssertion: Assertion
	
//	var kid: JWKIdentifier
//	var assertionSigner: JWTSigner
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(scope, forKey: .scope)
		try container.encode(grantType, forKey: .grantType)
		try container.encode(clientID, forKey: .clientID)
		try container.encode(clientSecret, forKey: .clientSecret)
//		try container.encode(clientAssertionType, forKey: .clientAssertionType)
//		try container.encode(assertionSigner.sign(clientAssertion, kid: kid), forKey: .clientAssertion)
	}
	
	private enum CodingKeys : String, CodingKey {
		case scope
		case clientID = "client_id"
		case clientSecret = "client_secret"
		case grantType = "grant_type"
//		case clientAssertionType = "client_assertion_type"
//		case clientAssertion = "client_assertion"
	}
	
}
