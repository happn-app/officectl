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
		let loggedInUser = req.auth.get(LoggedInUser.self)
		let context = LoginContext(username: loggedInUser?.userId.taggedId.id)
		return req.view.render("LoginPage", context)
	}
	
	func doLogin(_ req: Request) throws -> Response {
		return req.redirect(to: "/login", type: .normal)
	}
	
	private struct LoginContext : Encodable {
		var username: String?
	}
	
}
