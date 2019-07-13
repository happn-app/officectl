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
	
	func getReset(_ req: Request) throws -> ApiResponse<ApiPasswordReset> {
		/* General auth check */
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Parameter retrieval */
		let userId = try req.parameters.next(UserIdParameter.self)
		
		/* Only admins are allowed to see all password resets. Other users can
		 * only see their own password resets. */
		guard try token.payload.adm || token.payload.representsSameUserAs(userId: userId, container: req) else {
			throw Abort(.forbidden)
		}
		
		let sProvider = try req.make(OfficeKitServiceProvider.self)
		let (service, user) = try (userId.service, userId.service.logicalUser(fromUserId: userId.id, hints: [:]))
		
		let passwordResets = try sProvider
			.getAllServices(container: req)
			.filter{ $0.supportsPasswordChange }
			.map{ ResetPasswordActionAndService(destinationService: $0, sourceUser: user, sourceService: service, container: req) }
		return ApiResponse.data(ApiPasswordReset(userId: userId.taggedId, passwordResetAndServices: passwordResets, environment: req.environment))
	}
	
	func createReset(_ req: Request) throws -> Future<ApiResponse<ApiPasswordReset>> {
		/* General auth check */
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Parameter retrieval */
		let userId = try req.parameters.next(UserIdParameter.self)
		let passChangeData = try req.content.syncDecode(PassChangeData.self)
		
		/* Only admins are allowed to create a password reset for someone else
		 * than themselves. */
		guard try token.payload.adm || token.payload.representsSameUserAs(userId: userId, container: req) else {
			throw Abort(.forbidden)
		}
		
		let sProvider = try req.make(OfficeKitServiceProvider.self)
		let (service, user) = try (userId.service, userId.service.logicalUser(fromUserId: userId.id, hints: [:]))
		
		let authFuture: Future<Bool>
		if let oldPass = passChangeData.oldPassword {
			let authService = try sProvider.getDirectoryAuthenticatorService(container: req)
			let authServiceUser = try authService.logicalUser(fromUser: user, in: service, hints: [:])
			authFuture = try authService.authenticate(userId: authServiceUser.userId, challenge: oldPass, on: req)
		} else {
			/* Only admins are allowed to change the pass of someone without
			 * specifying the old password. */
			guard token.payload.adm else {throw Abort(.forbidden)}
			authFuture = req.future(true)
		}
		
		return authFuture
		.map{ verifiedOldPass in guard verifiedOldPass else {throw Abort(.forbidden)} }
		.map{ _ in
			/* The password of the user is verified. Let’s launch the resets!
			 * First, get them all. */
			let passwordResets = try sProvider
				.getAllServices(container: req)
				.filter{ $0.supportsPasswordChange }
				.map{ ResetPasswordActionAndService(destinationService: $0, sourceUser: user, sourceService: service, container: req) }
			
			/* Verify none of the resets are already executing. */
			guard !passwordResets.reduce(false, { $0 || $1.resetAction.successValue?.resetAction.isExecuting ?? false }) else {
				throw OperationAlreadyInProgressError()
			}
			/* Launch the resets. */
			passwordResets.forEach{ $0.resetAction.successValue?.resetAction.start(parameters: passChangeData.newPassword, weakeningMode: .always(successDelay: 180, errorDelay: 180), handler: nil) }
			
			/* Return the resets response. */
			return ApiResponse.data(ApiPasswordReset(userId: userId.taggedId, passwordResetAndServices: passwordResets, environment: req.environment))
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
