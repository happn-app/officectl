/*
 * UserSessionAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 17/04/2020.
 */

import Foundation

import JWTKit
import OfficeKit
import Vapor



struct UserSessionAuthenticator : AsyncSessionAuthenticator {
	
	typealias User = LoggedInUser
	
	func authenticate(sessionID: TaggedId, for request: Request) async throws {
		/* Let’s verify the user still exists and whether it is an admin */
		let sProvider = request.application.officeKitServiceProvider
		let authService = try sProvider.getDirectoryAuthenticatorService()
		let erasedUserId = try authService.userId(fromString: sessionID.id)
		
		guard sessionID.tag == authService.config.serviceId else {
			throw Abort(.forbidden, reason: "It seems your beloved admins changed the auth service of officectl. Don’t worry you don’t have to know what that means; simply login again. :)")
		}
		
		let futureUser = try authService.existingUser(fromUserId: erasedUserId, propertiesToFetch: [.identifyingEmail], using: request.services)
			.unwrap(or: Abort(.forbidden, reason: "The logged in user seems to have been deleted"))
		let futureIsAdmin = try authService.validateAdminStatus(userId: erasedUserId, using: request.services)
		
		return try await futureUser.and(futureIsAdmin).map{ userAndIsAdmin in
			let (user, isAdmin) = userAndIsAdmin
			request.auth.login(LoggedInUser(user: AnyDSUPair(service: authService, user: user), isAdmin: isAdmin))
		}
		.get()
	}
	
}
