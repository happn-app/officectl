/*
 * PasswordResetController.swift
 * officectl
 *
 * Created by François Lamboley on 09/05/2019.
 */

import Foundation

import JWT
import OfficeKit
import SemiSingleton
import Vapor



class PasswordResetController {
	
	func getReset(_ req: Request) throws -> EventLoopFuture<ApiResponse<ApiPasswordReset>> {
		/* General auth check */
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Parameter retrieval */
		let dsuIdPair = try req.parameters.next(AnyDSUIdPair.self)
		
		/* Only admins are allowed to see all password resets. Other users can
		 * only see their own password resets. */
		guard try token.payload.adm || token.payload.representsSameUserAs(dsuIdPair: dsuIdPair, container: req) else {
			throw Abort(.forbidden)
		}
		
		let sProvider = try req.make(OfficeKitServiceProvider.self)
		return try MultiServicesPasswordReset.fetch(from: dsuIdPair, in: sProvider.getAllServices(), on: req)
		.map{ passwordResets in ApiResponse.data(ApiPasswordReset(requestedUserId: dsuIdPair.taggedId, multiPasswordResets: passwordResets, environment: req.environment)) }
	}
	
	func createReset(_ req: Request) throws -> Future<ApiResponse<ApiPasswordReset>> {
		/* General auth check */
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Parameter retrieval */
		let dsuIdPair = try req.parameters.next(AnyDSUIdPair.self)
		let passChangeData = try req.content.syncDecode(PassChangeData.self)
		
		/* Only admins are allowed to create a password reset for someone else
		 * than themselves. */
		guard try token.payload.adm || token.payload.representsSameUserAs(dsuIdPair: dsuIdPair, container: req) else {
			throw Abort(.forbidden)
		}
		
		let sProvider = try req.make(OfficeKitServiceProvider.self)
		let dsuPair = try dsuIdPair.dsuPair()
		
		let authFuture: Future<Bool>
		if let oldPass = passChangeData.oldPassword {
			let authService = try sProvider.getDirectoryAuthenticatorService()
			let authServiceUser = try authService.logicalUser(fromUser: dsuPair.user, in: dsuPair.service)
			authFuture = try authService.authenticate(userId: authServiceUser.userId, challenge: oldPass, on: req)
		} else {
			/* Only admins are allowed to change the pass of someone without
			 * specifying the old password. */
			guard token.payload.adm else {throw Abort(.forbidden)}
			authFuture = req.future(true)
		}
		
		return authFuture
		.map{ verifiedOldPass in guard verifiedOldPass else {throw Abort(.forbidden)} }
		.flatMap{ _ in
			/* The password of the user is verified. Let’s fetch the resets! */
			return try MultiServicesPasswordReset.fetch(from: dsuIdPair, in: sProvider.getAllServices(), on: req)
		}
		.map{ resets in
			/* Then launch them. */
			try req.make(AuditLogger.self).log(action: "Launching password reset for user \(dsuIdPair.taggedId.stringValue).", source: .api(token: token.payload))
			_ = try resets.start(newPass: passChangeData.newPassword, weakeningMode: .always(successDelay: 180, errorDelay: 180), eventLoop: req.eventLoop)
			
			/* Return the resets response. */
			return ApiResponse.data(ApiPasswordReset(requestedUserId: dsuIdPair.taggedId, multiPasswordResets: resets, environment: req.environment))
		}
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
