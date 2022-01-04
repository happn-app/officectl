/*
 * AuthToken.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/29.
 */

import Foundation

import JWT
import UnwrapOrThrow
import Vapor

import OfficeKit
import OfficeModel



/* From https://datatracker.ietf.org/doc/html/draft-ietf-oauth-access-token-jwt#section-2.2 */
struct AuthToken : JWTPayload, Authenticatable {
	
	/** The issuer of the token. It’s “officectl”; see JWT specs for more info. */
	var iss: IssuerClaim = "officectl"
	
	/** A unique identifier for the token (for instance to be able to revoke it). */
	var jti = IDClaim(value: UUID().uuidString)
	
	/**
	 The audience of the token.
	 As per the spec we use the resource of the authorization grant.
	 We only have one resouce, so it’s always "https://office.1e42.net".
	 
	 This is either an array or a single element. As we only have one value we
	 use a single element instead of an array. */
	var aud: AudienceClaim = "https://office.happn.io"
	
	/** The ID of the user represented by the token. */
	var sub: TaggedID
	
	/** The expiration date of the token. */
	var exp: ExpirationClaim
	
	/** The date at which the access token was issued. */
	var iat: IssuedAtClaim
	
	/** The client ID that was used when generating the token. */
	var clientID: String
	
	var scope: String
	
	private enum CodingKeys : String, CodingKey {
		case iss, jti, aud, sub, exp, iat, scope
		case clientID = "client_id"
	}
	
	init(dsuIDPair: AnyDSUIDPair, clientID: String, expirationTime: TimeInterval = .init(15 * 60), scope: Set<AuthScope> = []) {
		self.sub = dsuIDPair.taggedID
		self.clientID = clientID
		
		self.iat = IssuedAtClaim(value: Date())
		self.exp = ExpirationClaim(value: self.iat.value + expirationTime)
		self.scope = scope.map{ $0.rawValue }.sorted().joined(separator: " ")
	}
	
	func verify(using signer: JWTSigner) throws {
		guard iss.value == "officectl" else {throw Abort(.unauthorized)}
		try exp.verifyNotExpired()
	}
	
	var authScopes: Set<AuthScope> {
		get throws {
			let authScopes = try scope
				.split(separator: " ")
				.map{ try AuthScope(rawValue: String($0)) ?! Abort(.badRequest) }
			return Set(authScopes)
		}
	}
	
	func requireScopes(_ scope: Set<AuthScope>) throws {
		guard try authScopes.isSuperset(of: scope) else {
			throw Abort(.forbidden)
		}
	}
	
}
