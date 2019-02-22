/*
 * setup_routes.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



func setup_routes(_ router: Router) throws {
	let loginController = LoginController()
	let passwordResetController = PasswordResetController()

	router.post("api", "auth", "login", use: loginController.login)
	
	router.get("password-reset", use: passwordResetController.showUserSelection)
	router.get("password-reset",  Email.parameter, use: passwordResetController.showResetPage)
	router.post("password-reset", Email.parameter, use: passwordResetController.resetPassword)
}
