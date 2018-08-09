/*
 * setup_routes.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import Vapor



func setup_routes(_ router: Router) throws {
	let resetPasswordController = PasswordResetController()
	router.get("password-reset", use: resetPasswordController.showUserSelection)
	router.get("password-reset", PathComponent.parameter("string"), use: resetPasswordController.showResetPage)
}
