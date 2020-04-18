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



struct UserBearerAuthenticator : BearerAuthenticator {
	
	func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
		return request.eventLoop.future()
		.flatMapThrowing{
			let sProvider = request.application.officeKitServiceProvider
			let jwtSecret = request.application.officectlConfig.jwtSecret
			let token: ApiAuth.Token = try JWTSigner.hs256(key: jwtSecret).verify(bearer.token)
			try request.auth.login(LoggedInUser(userId: AnyDSUIdPair(taggedId: token.sub, servicesProvider: sProvider), isAdmin: token.adm))
			/* Note: We do **not** verify the user exists or is admin. We could. But we assume the JWT expiring very fast we won’t have a problem. */
		}
	}
	
}
