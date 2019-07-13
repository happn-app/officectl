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
	
	#if false
	func createReset(_ req: Request) throws -> Future<ApiResponse<ApiPasswordReset>> {
		let userId = try req.parameters.next(UserIdParameter.self)
		let passChangeData = try req.content.syncDecode(PassChangeData.self)
		
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Only admins are allowed to create a password reset for someone else than themselves. */
		guard token.payload.adm || token.payload.sub == userId.distinguishedName?.stringValue else {
			throw Abort(.forbidden)
		}
		
		let user = User(id: userId)
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		
		let authFuture: Future<Void>
		if let oldPass = passChangeData.oldPassword {
			authFuture = try user.checkLDAPPassword(container: req, checkedPassword: oldPass)
		} else {
			/* Only admins are allowed to change the pass of someone without
			 * specifying the old password. */
			guard token.payload.adm else {
				throw Abort(.forbidden)
			}
			authFuture = req.eventLoop.newSucceededFuture(result: ())
		}
		
		return authFuture.map{ _ in
			/* The password of the user is verified. Let’s launch the reset! */
			let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: req) as ResetPasswordAction
			guard !resetPasswordAction.isExecuting else {throw OperationAlreadyInProgressError()}
			resetPasswordAction.start(parameters: passChangeData.newPassword, handler: nil)
			return ApiResponse.data(ApiPasswordReset(passwordReset: resetPasswordAction))
		}
	}
	
	func deleteReset(_ req: Request) throws -> Future<ApiResponse<ApiPasswordReset>> {
		throw NotImplementedError()
	}
	#endif
	
	private struct PassChangeData : Decodable {
		
		var oldPassword: String?
		var newPassword: String
		
		private enum CodingKeys : String, CodingKey {
			
			case oldPassword = "old_password"
			case newPassword = "new_password"
			
		}
		
	}
	
}
