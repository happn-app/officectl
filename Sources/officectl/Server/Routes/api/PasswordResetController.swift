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
	
	func getResets(_ req: Request) throws -> Future<ApiResponse<[ApiPasswordReset]>> {
		throw NotImplementedError()
	}
	
	func getReset(_ req: Request) throws -> ApiResponse<ApiPasswordReset> {
		let userId = try req.parameters.next(UserId.self)
		
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Only admins are allowed to see any password reset. */
		guard token.payload.adm || token.payload.sub == userId.distinguishedName?.stringValue else {
			throw Abort(.forbidden)
		}
		
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: User(id: userId), additionalInitInfo: req) as ResetPasswordAction
		return ApiResponse.data(ApiPasswordReset(passwordReset: resetPasswordAction))
	}
	
	func createReset(_ req: Request) throws -> Future<ApiResponse<ApiPasswordReset>> {
		let userId = try req.parameters.next(UserId.self)
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
	
	private struct PassChangeData : Decodable {
		
		var oldPassword: String?
		var newPassword: String
		
		private enum CodingKeys : String, CodingKey {
			
			case oldPassword = "old_password"
			case newPassword = "new_password"
			
		}
		
	}
	
}
