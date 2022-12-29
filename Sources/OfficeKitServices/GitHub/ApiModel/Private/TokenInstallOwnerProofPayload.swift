/*
 * TokenInstallOwnerProofPayload.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/29.
 */

import Foundation

import JWT



struct TokenInstallOwnerProofPayload : JWTPayload {
	
	var iss: IssuerClaim
	var iat: IssuedAtClaim
	var exp: ExpirationClaim
	
	func verify(using signer: JWTKit.JWTSigner) throws {
		/* We do not verify the token, the server will. */
		throw Err.unsupportedOperation
	}
	
}
