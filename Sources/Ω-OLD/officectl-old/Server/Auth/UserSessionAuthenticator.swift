/*
 * UserSessionAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 2020/04/17.
 */

import Foundation

import JWT
import Vapor

import OfficeKit
import OfficeModel



struct UserSessionAuthenticator : AsyncSessionAuthenticator {
	
	typealias User = LoggedInUser
	
	func authenticate(sessionID: TaggedID, for request: Request) async throws {
		/* Let’s verify the user still exists and whether it is an admin */
		let sProvider = request.application.officeKitServiceProvider
		let authService = try sProvider.getDirectoryAuthenticatorService()
		let erasedUserID = try authService.userID(fromString: sessionID.id)
		
		guard sessionID.tag == authService.config.serviceID else {
			throw Abort(.forbidden, reason: "It seems your beloved admins changed the auth service of officectl. Don’t worry you don’t have to know what that means; simply login again. :)")
		}
		
		guard let user = try await authService.existingUser(fromUserID: erasedUserID, propertiesToFetch: [.identifyingEmail], using: request.services) else {
			throw Abort(.forbidden, reason: "The logged in user seems to have been deleted")
		}
		let isAdmin = try await authService.validateAdminStatus(userID: erasedUserID, using: request.services)
		request.auth.login(LoggedInUser(user: AnyDSUPair(service: authService, user: user), scopes: isAdmin ? [.admin] : []))
	}
	
}
