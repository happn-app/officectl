/*
 * WebLoginController.swift
 * officectl
 *
 * Created by François Lamboley on 2020/04/16.
 */

import Foundation

import NIO
import OfficeKit
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
	
	func doLogin(_ req: Request) throws -> Response {
		struct LoginData : Decodable {
			var nextURLPath: String?
		}
		
		let loginData = try? req.content.decode(LoginData.self)
		return req.redirect(to: loginData?.nextURLPath ?? "/", type: .normal)
	}
	
}
