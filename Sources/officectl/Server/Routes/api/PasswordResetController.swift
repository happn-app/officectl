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
	
	func getReset(_ req: Request) throws -> Future<ApiResponse<ApiPasswordReset>> {
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
		return req.eventLoop.newSucceededFuture(result: ApiResponse.data(ApiPasswordReset(passwordReset: resetPasswordAction)))
	}
	
	func createReset(_ req: Request) throws -> Future<ApiResponse<ApiPasswordReset>> {
		throw NotImplementedError()
	}
	
	func deleteReset(_ req: Request) throws -> Future<ApiResponse<ApiPasswordReset>> {
		throw NotImplementedError()
	}
	
}
