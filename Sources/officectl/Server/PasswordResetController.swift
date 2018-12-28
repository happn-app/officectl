/*
 * PasswordResetController.swift
 * officectl
 *
 * Created by François Lamboley on 09/08/2018.
 */

import Foundation

import SemiSingleton
import Vapor

import OfficeKit



final class PasswordResetController {
	
	func showUserSelection(_ req: Request) throws -> Future<View> {
		return try req.view().render("PasswordResetPage")
	}
	
	func showResetPage(_ req: Request) throws -> Future<View> {
		let email = try req.parameters.next(Email.self)
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		#warning("TODO: We must provide the base DN in a config or via the command line")
		let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: User(email: email, baseDN: LDAPDistinguishedName(values: [(key: "ou", value: "people"), (key: "dc", value: "happn"), (key: "dc", value: "com")]))) as ResetPasswordAction
		
		if !resetPasswordAction.isExecuting {
			return try req.view().render("PasswordResetPage", ["user_email": email.stringValue])
		} else {
			return try req.view().render("PasswordResetInProgressPage", ["user_email": email.stringValue])
		}
	}
	
	func resetPassword(_ req: Request) throws -> Future<View> {
		let view = try req.view()
		let email = try req.parameters.next(Email.self)
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		let resetPasswordData = try req.content.syncDecode(ResetPasswordData.self)
		#warning("TODO: We must provide the base DN in a config or via the command line")
		let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: User(email: email, baseDN: LDAPDistinguishedName(values: [(key: "ou", value: "people"), (key: "dc", value: "happn"), (key: "dc", value: "com")]))) as ResetPasswordAction
		
		return try resetPasswordAction.start(oldPassword: resetPasswordData.oldPass, newPassword: resetPasswordData.newPass, container: req)
		.then{ _ in
			assert(resetPasswordAction.isExecuting)
			return view.render("PasswordResetInProgressPage", ["user_email": email.stringValue])
		}
	}
	
	private struct ResetPasswordData : Decodable {
		
		var oldPass: String
		var newPass: String
		
	}
	
}
