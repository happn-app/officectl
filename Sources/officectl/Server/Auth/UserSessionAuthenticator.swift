/*
 * UserSessionAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 2020/04/17.
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
		
		guard let user = try await authService.existingUser(fromUserId: erasedUserId, propertiesToFetch: [.identifyingEmail], using: request.services) else {
			throw Abort(.forbidden, reason: "The logged in user seems to have been deleted")
		}
		let isAdmin = try await authService.validateAdminStatus(userId: erasedUserId, using: request.services)
		request.auth.login(LoggedInUser(user: AnyDSUPair(service: authService, user: user), isAdmin: isAdmin))
	}
	
}
