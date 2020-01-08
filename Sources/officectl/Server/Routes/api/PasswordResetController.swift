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
	
	func getReset(_ req: Request) throws -> EventLoopFuture<ApiResponse<ApiPasswordReset>> {
		/* General auth check */
		let officectlConfig = req.application.officectlConfig
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token: ApiAuth.Token = try JWTSigner.hs256(key: officectlConfig.jwtSecret).verify(bearer.token)
		
		/* Parameter retrieval */
		let dsuIdPair = try AnyDSUIdPair.getAsParameter(named: "dsuid-pair", from: req)
		
		/* Only admins are allowed to see all password resets. Other users can
		 * only see their own password resets. */
		guard try token.adm || token.representsSameUserAs(dsuIdPair: dsuIdPair, request: req) else {
			throw Abort(.forbidden)
		}
		
		let sProvider = req.application.officeKitServiceProvider
		return try MultiServicesPasswordReset.fetch(from: dsuIdPair, in: sProvider.getAllUserDirectoryServices(), using: req.services)
		.map{ passwordResets in ApiResponse.data(ApiPasswordReset(requestedUserId: dsuIdPair.taggedId, multiPasswordResets: passwordResets, environment: req.application.environment)) }
	}
	
	func createReset(_ req: Request) throws -> EventLoopFuture<ApiResponse<ApiPasswordReset>> {
		/* General auth check */
		let officectlConfig = req.application.officectlConfig
		guard let bearer = req.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token: ApiAuth.Token = try JWTSigner.hs256(key: officectlConfig.jwtSecret).verify(bearer.token)
		
		/* Parameter retrieval */
		let dsuIdPair = try AnyDSUIdPair.getAsParameter(named: "dsuid-pair", from: req)
		let passChangeData = try req.content.decode(PassChangeData.self)
		
		/* Only admins are allowed to create a password reset for someone else
		 * than themselves. */
		guard try token.adm || token.representsSameUserAs(dsuIdPair: dsuIdPair, request: req) else {
			throw Abort(.forbidden)
		}
		
		let sProvider = req.application.officeKitServiceProvider
		let dsuPair = try dsuIdPair.dsuPair()
		
		let authFuture: EventLoopFuture<Bool>
		if let oldPass = passChangeData.oldPassword {
			let authService = try sProvider.getDirectoryAuthenticatorService()
			let authServiceUser = try authService.logicalUser(fromUser: dsuPair.user, in: dsuPair.service)
			authFuture = try authService.authenticate(userId: authServiceUser.userId, challenge: oldPass, using: req.services)
		} else {
			/* Only admins are allowed to change the pass of someone without
			 * specifying the old password. */
			guard token.adm else {throw Abort(.forbidden)}
			authFuture = req.eventLoop.future(true)
		}
		
		return authFuture
		.flatMapThrowing{ verifiedOldPass in guard verifiedOldPass else {throw Abort(.forbidden)} }
		.flatMapThrowing{ _ in
			/* The password of the user is verified. Let’s fetch the resets! */
			return try MultiServicesPasswordReset.fetch(from: dsuIdPair, in: sProvider.getAllUserDirectoryServices(), using: req.services)
		}
		.flatMap{ $0 }
		.flatMapThrowing{ resets in
			/* Then launch them. */
			try req.application.auditLogger.log(action: "Launching password reset for user \(dsuIdPair.taggedId.stringValue).", source: .api(token: token))
			_ = try resets.start(newPass: passChangeData.newPassword, weakeningMode: .always(successDelay: 180, errorDelay: 180), eventLoop: req.eventLoop)
			
			/* Return the resets response. */
			return ApiResponse.data(ApiPasswordReset(requestedUserId: dsuIdPair.taggedId, multiPasswordResets: resets, environment: req.application.environment))
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
