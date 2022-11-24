/*
 * TokenRequestBody.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/24.
 */

import Foundation

@preconcurrency import JWT



struct TokenRequestBody : Sendable, Encodable {
	
	struct Assertion : JWTPayload {
		var iss: IssuerClaim
		var scope: String
		var aud: AudienceClaim
		var iat: IssuedAtClaim
		var exp: ExpirationClaim
		var sub: SubjectClaim?
		func verify(using signer: JWTSigner) throws {
			/* We do not verify the token, the server will. */
			throw Err.unsupportedOperation
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
