/*
 * WebLoginController.swift
 * officectl
 *
 * Created by François Lamboley on 2020/04/16.
 */

import Foundation

import Email
import NIO
import OfficeKit
import UnwrapOrThrow
import Vapor



class WebLoginController {
	
	func authCheck(_ req: Request) throws -> String {
		/* If we get through here, we are logged in as per the route setup */
		return "OK"
	}
	
	func showLoginPage(_ req: Request) async throws -> View {
		struct LoginContext : Encodable {
			var username: String?
			var nextURLPath: String?
		}
		
		let context = LoginContext(
			username: req.auth.get(LoggedInUser.self)?.user.taggedId.id,
			nextURLPath: req.headers["Officectl-Login-Next-Page"].last ?? req.query["next"]
		)
		return try await req.view.render("Login", context)
	}
	
	func doLogin(_ req: Request) async throws -> Response {
		struct LoginData : Decodable {
			var username: String
			var password: String
			var nextURLPath: String?
		}
		let loginData = try req.content.decode(LoginData.self)
		
		let sProvider = req.application.officeKitServiceProvider
		let authService = try sProvider.getDirectoryAuthenticatorService()
		
		let userPair = try AnyDSUPair(service: authService, user: authService.logicalUser(fromEmail: Email(rawValue: loginData.username) ?! "Invalid email", servicesProvider: sProvider))
		
		guard try await authService.authenticate(userId: userPair.user.userId, challenge: loginData.password, using: req.services) else {
			throw Abort(.forbidden, reason: "Invalid credentials. Please check your username and password.")
		}
		let isAdmin = try await authService.validateAdminStatus(userId: userPair.user.userId, using: req.services)
		/* The password of the user is verified and we have its admin status.
		 * Let’s log it in. */
		req.auth.login(LoggedInUser(user: userPair, scopes: isAdmin ? [.admin] : []))
		
		return req.redirect(to: loginData.nextURLPath ?? "/", type: .normal)
	}
	
}
