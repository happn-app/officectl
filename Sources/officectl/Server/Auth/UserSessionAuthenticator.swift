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



struct UserSessionAuthenticator : SessionAuthenticator {
	
	typealias User = LoggedInUser
	
	func authenticate(sessionID: TaggedId, for request: Request) -> EventLoopFuture<Void> {
		return request.eventLoop.future()
		.flatMapThrowing{
			/* Let’s verify the user still exists and whether it is an admin */
			let sProvider = request.application.officeKitServiceProvider
			let authService = try sProvider.getDirectoryAuthenticatorService()
			let erasedUserId = try authService.userId(fromString: sessionID.id)
			
			guard sessionID.tag == authService.config.serviceId else {
				throw Abort(.forbidden, reason: "It seems your beloved admins changed the auth service of officectl. Don’t worry you don’t have to know what that means; simply login again. :)")
			}
			
			let userExists = try authService.existingUser(fromUserId: erasedUserId, propertiesToFetch: [], using: request.services)
				.unwrap(or: Abort(.forbidden, reason: "The logged in user seems to have been deleted"))
			let userIsAdmin = try authService.validateAdminStatus(userId: erasedUserId, using: request.services)
			
			return userExists.and(userIsAdmin).flatMapThrowing{ existsAndIsAdmin in
				let (_, isAdmin) = existsAndIsAdmin
				try request.auth.login(LoggedInUser(userId: AnyDSUIdPair(taggedId: sessionID, servicesProvider: sProvider), isAdmin: isAdmin))
			}
		}
		.flatMap{ $0 }
	}
	
}
