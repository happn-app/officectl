/*
 * PasswordResetController.swift
 * officectl
 *
 * Created by François Lamboley on 09/05/2019.
 */

import Foundation

import JWTKit
import OfficeKit
import SemiSingleton
import Vapor



class PasswordResetController {
	
	func getReset(_ req: Request) async throws -> ApiResponse<ApiPasswordReset> {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		let fetchedUserId = try AnyDSUIdPair.getAsParameter(named: "dsuid-pair", from: req)
		guard try loggedInUser.isAdmin || loggedInUser.representsSameUserAs(dsuIdPair: fetchedUserId, request: req) else {
			throw Abort(.forbidden, reason: "Non-admin users can only see their own password resets.")
		}
		
		let sProvider = req.application.officeKitServiceProvider
		let passwordResets = try await MultiServicesPasswordReset.fetch(from: fetchedUserId, in: sProvider.getAllUserDirectoryServices(), using: req.services)
		return ApiResponse.data(ApiPasswordReset(requestedUserId: fetchedUserId.taggedId, multiPasswordResets: passwordResets, environment: req.application.environment))
	}
	
	func createReset(_ req: Request) async throws -> ApiResponse<ApiPasswordReset> {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		
		/* Parameter retrieval */
		let dsuIdPair = try AnyDSUIdPair.getAsParameter(named: "dsuid-pair", from: req)
		let passChangeData = try req.content.decode(PassChangeData.self)
		
		/* Only admins are allowed to create a password reset for someone else
		 * than themselves. */
		guard try loggedInUser.isAdmin || loggedInUser.representsSameUserAs(dsuIdPair: dsuIdPair, request: req) else {
			throw Abort(.forbidden, reason: "Non-admin users can only reset their own password.")
		}
		
		let sProvider = req.application.officeKitServiceProvider
		let dsuPair = try dsuIdPair.dsuPair()
		
		/* Verify user authorization */
		if let oldPass = passChangeData.oldPassword {
			let authService = try sProvider.getDirectoryAuthenticatorService()
			let authServiceUser = try authService.logicalUser(fromUser: dsuPair.user, in: dsuPair.service)
			guard try await authService.authenticate(userId: authServiceUser.userId, challenge: oldPass, using: req.services) else {
				throw Abort(.forbidden, reason: "Invalid old password")
			}
		} else {
			/* Only admins are allowed to change the pass of someone without specifying the old password. */
			guard loggedInUser.isAdmin else {
				throw Abort(.forbidden, reason: "Old password is required for non-admin users")
			}
		}
		
		/* The password of the user is verified. Let’s fetch the resets! */
		let resets = try await MultiServicesPasswordReset.fetch(from: dsuIdPair, in: sProvider.getAllUserDirectoryServices(), using: req.services)
		/* Then launch them. */
		try req.application.auditLogger.log(action: "Launching password reset for user \(dsuIdPair.taggedId.stringValue).", source: .api(user: loggedInUser))
		Task.detached{ try await resets.start(newPass: passChangeData.newPassword, weakeningMode: .always(successDelay: 180, errorDelay: 180)) }
		
		/* Return the resets response. */
		return ApiResponse.data(ApiPasswordReset(requestedUserId: dsuIdPair.taggedId, multiPasswordResets: resets, environment: req.application.environment))
	}
	
	private struct PassChangeData : Decodable {
		
		var oldPassword: String?
		var newPassword: String
		
		private enum CodingKeys : String, CodingKey {
			
			case oldPassword = "old_password"
			case newPassword = "new_password"
			
		}
		
	}
	
}
