/*
 * LoginController.swift
 * officectl
 *
 * Created by François Lamboley on 22/02/2019.
 */

import Foundation

import JWTKit
import OfficeKit
import Vapor



class LoginController {
	
	func login(_ req: Request) throws -> EventLoopFuture<ApiResponse<ApiAuth>> {
		let loginData = try req.content.decode(LoginData.self)
		
		let config = req.make(OfficectlConfig.self)
		let authService = try req.make(OfficeKitServiceProvider.self).getDirectoryAuthenticatorService()
		
		let userId = try AnyDSUIdPair(string: loginData.username, servicesProvider: req.make())
		guard userId.service.config.serviceId == authService.config.serviceId else {
			throw InvalidArgumentError(message: "Tried to login with an id which is not from the auth service.")
		}
		
		
		return try authService.authenticate(userId: userId.userId, challenge: loginData.password, on: req.eventLoop)
		.flatMapThrowing{ authSuccess -> Void in
			guard authSuccess else {throw InvalidArgumentError(message: "Cannot login with these credentials.")}
			return ()
		}
		.flatMapThrowing{ _ -> EventLoopFuture<Bool> in
			return try authService.validateAdminStatus(userId: userId.userId, on: req.eventLoop)
		}
		.flatMap{ $0 }
		.flatMapThrowing{ isAdmin in
			/* The password of the user is verified. Let’s return the relevant
			 * data. */
			let token = ApiAuth.Token(dsuIdPair: userId, admin: isAdmin, validityDuration: 30*60) /* 30 minutes */
			guard let tokenString = String(data: try Data(JWT(payload: token).sign(using: .hs256(key: config.jwtSecret))), encoding: .utf8) else {
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
