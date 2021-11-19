/*
 * ApiAuth.swift
 * officectl
 *
 * Created by François Lamboley on 22/02/2019.
 */

import Foundation

import JWTKit
import OfficeKit
import Vapor



struct ApiAuth : Codable {
	
	var token: String
	var expirationDate: Date
	
	var isAdmin: Bool
	
	init(token t: String, expirationDate d: Date, isAdmin a: Bool) {
		token = t
		expirationDate = d
		isAdmin = a
	}
	
	struct Token : JWTPayload {
		
		/** The issuer of the token. Should always be “officectl”. */
		var iss = "officectl"
		
		var jti = UUID().uuidString
		
		var aud = URL(string: "https://office.happn.io")!
		
		/** The tagged id of the authenticated person. Should always be tagged
		with the auth service. */
		var sub: TaggedId
		
		/** The expiration time of the token. */
		var exp: ExpirationClaim
		
		/** Is the user admin? */
		var adm: Bool
		
		init(dsuIdPair: AnyDSUIdPair, admin: Bool, validityDuration: TimeInterval) {
			adm = admin
			sub = dsuIdPair.taggedId
			exp = .init(value: Date(timeIntervalSinceNow: validityDuration))
		}
		
		func verify(using signer: JWTSigner) throws {
			guard iss == "officectl" else {throw Abort(.unauthorized)}
			try exp.verifyNotExpired()
		}
		
		func representsSameUserAs(dsuIdPair: AnyDSUIdPair, request: Request) throws -> Bool {
			let sProvider = request.application.officeKitServiceProvider
			let authService = try sProvider.getDirectoryAuthenticatorService()
			return try sub == dsuIdPair.dsuPair().hop(to: authService).taggedId
		}
		
	}
	
}
