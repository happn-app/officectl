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
		let basePeopleDN = try nil2throw(req.make(OfficeKitConfig.self).ldapConfigOrThrow().peopleBaseDN, "LDAP People Base DN")
		let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: User(email: email, basePeopleDN: basePeopleDN), additionalInitInfo: req) as ResetPasswordAction
		
		return try renderResetPasswordAction(resetPasswordAction, view: req.view())
	}
	
	func resetPassword(_ req: Request) throws -> Future<View> {
		let view = try req.view()
		let email = try req.parameters.next(Email.self)
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		let resetPasswordData = try req.content.syncDecode(ResetPasswordData.self)
		let basePeopleDN = try nil2throw(req.make(OfficeKitConfig.self).ldapConfigOrThrow().peopleBaseDN, "LDAP People Base DN")
		let user = User(email: email, basePeopleDN: basePeopleDN)
		
		return try user
		.checkLDAPPassword(container: req, checkedPassword: resetPasswordData.oldPass)
		.then{ _ in
			/* The password of the user is verified. Let’s launch the reset! */
			let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: req) as ResetPasswordAction
			resetPasswordAction.start(parameters: resetPasswordData.newPass, handler: nil)
			return self.renderResetPasswordAction(resetPasswordAction, view: view)
		}
	}
	
	private struct ResetPasswordData : Decodable {
		
		var oldPass: String
		var newPass: String
		
	}
	
	private func renderResetPasswordAction(_ resetPasswordAction: ResetPasswordAction, view: ViewRenderer) -> EventLoopFuture<View> {
		let emailStr = resetPasswordAction.subject.email?.stringValue ?? "<unknown>"
		if !resetPasswordAction.isExecuting {
			return view.render("PasswordResetPage", ["user_email": emailStr])
		} else {
			return view.render("PasswordResetInProgressPage", ["user_email": emailStr])
		}
	}
	
}
