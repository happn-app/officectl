/*
 * UserCredsAuthenticator.swift
 * officectl
 *
 * Created by François Lamboley on 17/04/2020.
 */

import Foundation

import Email
import OfficeKit
import Vapor



struct UserCredsAuthenticator : AsyncCredentialsAuthenticator {
	
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
	
	func authenticate(credentials loginData: LoginData, for request: Request) async throws {
		let sProvider = request.application.officeKitServiceProvider
		let authService = try sProvider.getDirectoryAuthenticatorService()
		
		let user: AnyDSUPair
		switch self.usernameType {
			case .email:    user = try AnyDSUPair(service: authService, user: authService.logicalUser(fromEmail: nil2throw(Email(rawValue: loginData.username), "Invalid email"), servicesProvider: sProvider))
			case .taggedId: user = try AnyDSUIdPair(string: loginData.username, servicesProvider: sProvider).dsuPair()
		}
		guard user.service.config.serviceId == authService.config.serviceId else {
			throw Abort(.forbidden, reason: "Tried to login with an id which is not from the auth service (expected \(authService.config.serviceId)).")
		}
		
		guard try await authService.authenticate(userId: user.user.userId, challenge: loginData.password, using: request.services) else {
			throw Abort(.forbidden, reason: "Invalid credentials. Please check your username and password.")
		}
		let isAdmin = try await authService.validateAdminStatus(userId: user.user.userId, using: request.services)
		request.auth.login(LoggedInUser(user: user, isAdmin: isAdmin))
	}
	
}
