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
	router.post("api", "auth", "login",  use: LoginController().login)
	router.post("api", "auth", "logout", use: LogoutController().logout)
	
	let usersController = UsersController()
	router.get("api", "users", use: usersController.getUsers)
	router.get("api", "users", UserId.parameter, use: usersController.getUser)
	
	let passwordResetController = PasswordResetController()
	router.get("api", "password-resets", use: passwordResetController.getResets)
	router.get("api", "password-resets", UserId.parameter, use: passwordResetController.getReset)
	router.put("api", "password-resets", UserId.parameter, use: passwordResetController.createReset)
	router.delete("api", "password-resets", UserId.parameter, use: passwordResetController.deleteReset)
	
	/* ******** Temporary password reset page ******** */
	
	let webPasswordResetController = WebPasswordResetController()
	router.get("password-reset", use: webPasswordResetController.showUserSelection)
	router.get("password-reset",  Email.parameter, use: webPasswordResetController.showResetPage)
	router.post("password-reset", Email.parameter, use: webPasswordResetController.resetPassword)
}
