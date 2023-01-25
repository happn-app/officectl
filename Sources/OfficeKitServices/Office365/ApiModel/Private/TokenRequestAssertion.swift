/*
 * TokenRequestAssertion.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

@preconcurrency import JWT



struct TokenRequestAssertion : JWTPayload {
	
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
