/*
 * WebLoginController.swift
 * officectl
 *
 * Created by François Lamboley on 16/04/2020.
 */

import Foundation

import NIO
import OfficeKit
import Vapor



class WebLoginController {
	
	func showLoginPage(_ req: Request) throws -> EventLoopFuture<View> {
		struct LoginContext : Encodable {
			var username: String?
			var nextURLPath: String?
		}
		
		let context = LoginContext(
			username: req.auth.get(LoggedInUser.self)?.userId.taggedId.id,
			nextURLPath: req.headers["Officectl-Login-Next-Page"].last ?? req.query["next"]
		)
		return req.view.render("LoginPage", context)
	}
	
	func doLogin(_ req: Request) throws -> Response {
		struct LoginData : Decodable {
			var nextURLPath: String?
		}
		
		let loginData = try? req.content.decode(LoginData.self)
		return req.redirect(to: loginData?.nextURLPath ?? "/", type: .normal)
	}
	
}
