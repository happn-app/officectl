/*
 * LoginController.swift
 * officectl
 *
 * Created by François Lamboley on 22/02/2019.
 */

import Foundation

import JWT
import OfficeKit
import Vapor



class LoginController {
	
	func login(_ req: Request) throws -> Future<ApiResponse<ApiAuth>> {
		let loginData = try req.content.syncDecode(LoginData.self)
		
		let config = try req.make(OfficectlConfig.self)
		let authService = try req.make(OfficeKitServiceProvider.self).getDirectoryAuthenticatorService()
		
		let userId = try AnyDSUIdPair(string: loginData.username, servicesProvider: req.make())
		guard userId.service.config.serviceId == authService.config.serviceId else {
			throw BasicValidationError("Tried to login with an id which is not from the auth service.")
		}
		
		
		return try authService.authenticate(userId: userId.userId, challenge: loginData.password, on: req)
		.map{ authSuccess -> Void in
			guard authSuccess else {throw BasicValidationError("Cannot login with these credentials.")}
			return ()
		}
		.flatMap{ _ -> Future<Bool> in
			return try authService.validateAdminStatus(userId: userId.userId, on: req)
		}
		.map{ isAdmin in
			/* The password of the user is verified. Let’s return the relevant
			 * data. */
			let token = ApiAuth.Token(userId: userId, admin: isAdmin, validityDuration: 30*60) /* 30 minutes */
			guard let tokenString = String(data: try JWT(payload: token).sign(using: .hs256(key: config.jwtSecret)), encoding: .utf8) else {
				throw Abort(.internalServerError)
			}
			
			return .data(ApiAuth(token: tokenString, expirationDate: token.exp, isAdmin: token.adm))
		}
	}
	
	private struct LoginData : Decodable {
		
		var username: String
		var password: String
		
	}
	
}
