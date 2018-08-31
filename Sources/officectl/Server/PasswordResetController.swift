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
		let user = try req.parameters.next(HappnUser.self)
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: user) as ResetPasswordAction
		return try req.view().render("PasswordResetPage", ["user_email": user.email.stringValue])
	}
	
	func resetPassword(_ req: Request) throws -> Future<View> {
		let view = try req.view()
		let user = try req.parameters.next(HappnUser.self)
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		let resetPasswordData = try req.content.syncDecode(ResetPasswordData.self)
		let resetPasswordAction = semiSingletonStore.semiSingleton(forKey: user) as ResetPasswordAction
		return try resetPasswordAction.start(oldPassword: resetPasswordData.oldPass, newPassword: resetPasswordData.newPass, container: req)
		.then{ _ in
			assert(resetPasswordAction.isExecuting)
			return view.render("PasswordResetInProgressPage", ["user_email": user.email.stringValue])
		}
	}
	
	private struct ResetPasswordData : Decodable {
		
		var oldPass: String
		var newPass: String
		
	}
	
}
