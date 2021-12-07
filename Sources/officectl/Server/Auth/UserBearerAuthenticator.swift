/*
 * UserBearerAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 17/04/2020.
 */

import Foundation

import JWTKit
import OfficeKit
import Vapor



struct UserBearerAuthenticator : AsyncBearerAuthenticator {
	
	func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
		let sProvider = request.application.officeKitServiceProvider
		let jwtSecret = try nil2throw(request.application.officectlConfig.serverConfig?.jwtSecret)
		let token: ApiAuth.Token = try JWTSigner.hs256(key: jwtSecret).verify(bearer.token)
		try request.auth.login(LoggedInUser(user: AnyDSUIdPair(taggedId: token.sub, servicesProvider: sProvider).dsuPair(), isAdmin: token.adm))
		/* Note: We do **not** verify the user exists or is admin. We could. But we assume the JWT expiring very fast we won’t have a problem. */
	}
	
}
