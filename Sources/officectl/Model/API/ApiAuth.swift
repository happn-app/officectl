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
		
		/** The audience of the token. Should always be “officectl”. */
		var aud = "officectl"
		
		var jti = UUID().uuidString
		
		/** The tagged id of the authenticated person. Should always be tagged
		with the auth service. */
		var sub: TaggedId
		
		/** The expiration time of the token. */
		var exp: Date
		
		/** Is the user admin? */
		var adm: Bool
		
		init(dsuIdPair: AnyDSUIdPair, admin: Bool, validityDuration: TimeInterval) {
			adm = admin
			sub = dsuIdPair.taggedId
			exp = Date(timeIntervalSinceNow: validityDuration)
		}
		
		func verify(using signer: JWTSigner) throws {
			guard aud == "officectl" else {throw Abort(.unauthorized)}
			guard exp.timeIntervalSinceNow > 0 else {throw Abort(.unauthorized)}
		}
		
		func representsSameUserAs(dsuIdPair: AnyDSUIdPair, request: Request) throws -> Bool {
			let sProvider = request.application.officeKitServiceProvider
			let authService = try sProvider.getDirectoryAuthenticatorService()
			return try sub == dsuIdPair.dsuPair().hop(to: authService).taggedId
		}
		
	}
	
}
