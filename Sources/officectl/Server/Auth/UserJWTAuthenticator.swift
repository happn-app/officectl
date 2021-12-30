/*
 * UserBearerAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 2020/04/17.
 */

import Foundation

import JWT
import OfficeKit
import Vapor



struct UserJWTAuthenticator : AsyncJWTAuthenticator {
	
	func authenticate(jwt payload: AuthToken, for request: Request) async throws {
		/* jwt payload is already verified here. */
		let sProvider = request.application.officeKitServiceProvider
		try request.auth.login(LoggedInUser(user: AnyDSUIdPair(taggedId: payload.sub, servicesProvider: sProvider).dsuPair(), scopes: payload.authScopes))
		/* Note: We do **not** verify the user exists or is admin. We could. But we assume the JWT expiring very fast we won’t have a problem. */
	}
	
}
