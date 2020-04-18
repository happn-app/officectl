/*
 * UserCredsAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 17/04/2020.
 */

import Foundation

import OfficeKit
import Vapor



struct UserCredsAuthenticator : CredentialsAuthenticator {
	
	struct LoginData : Content {
		
		var username: String
		var password: String
		
	}
	
	typealias Credentials = LoginData
	
	func authenticate(credentials loginData: LoginData, for request: Request) -> EventLoopFuture<Void> {
		return request.eventLoop.future()
		.flatMapThrowing{
			let authService = try request.application.officeKitServiceProvider.getDirectoryAuthenticatorService()
			
			let userId = try AnyDSUIdPair(string: loginData.username, servicesProvider: request.application.officeKitServiceProvider)
			guard userId.service.config.serviceId == authService.config.serviceId else {
				throw Abort(.forbidden, reason: "Tried to login with an id which is not from the auth service (expected \(authService.config.serviceId)).")
			}
			
			return try authService.authenticate(userId: userId.userId, challenge: loginData.password, using: request.services)
			.flatMapThrowing{ authSuccess -> Void in
				guard authSuccess else {throw Abort(.forbidden, reason: "Invalid credentials. Please check your username and password.")}
				return ()
			}
			.flatMapThrowing{ _ -> EventLoopFuture<Bool> in
				return try authService.validateAdminStatus(userId: userId.userId, using: request.services)
			}
			.flatMap{ $0 }
			.flatMapThrowing{ isAdmin in
				/* The password of the user is verified and we have its admin
				 * status. Let’s log it in. */
				request.auth.login(LoggedInUser(userId: userId, isAdmin: isAdmin))
				return ()
			}
		}
		.flatMap{ $0 }
	}
	
}
