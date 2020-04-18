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
	
	typealias Credentials = LoginData
	
	struct LoginData : Content {
		
		var username: String
		var password: String
		
	}
	
	enum UsernameType {
		
		case taggedId
		case email
		
	}
	
	var usernameType: UsernameType
	
	init(usernameType ut: UsernameType = .taggedId) {
		usernameType = ut
	}
	
	func authenticate(credentials loginData: LoginData, for request: Request) -> EventLoopFuture<Void> {
		return request.eventLoop.future()
		.flatMapThrowing{
			let sProvider = request.application.officeKitServiceProvider
			let authService = try sProvider.getDirectoryAuthenticatorService()
			
			let userId: AnyDSUIdPair
			switch self.usernameType {
			case .email:    userId = try AnyDSUIdPair(service: authService, userId: authService.logicalUser(fromEmail: nil2throw(Email(string: loginData.username), "Invalid email"), servicesProvider: sProvider).userId)
			case .taggedId: userId = try AnyDSUIdPair(string: loginData.username, servicesProvider: sProvider)
			}
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
