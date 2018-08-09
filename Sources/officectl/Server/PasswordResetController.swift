/*
 * PasswordResetController.swift
 * officectl
 *
 * Created by François Lamboley on 09/08/2018.
 */

import Foundation

import Vapor



final class PasswordResetController {
	
	func index(_ req: Request) throws -> Future<View> {
		return try req.view().render("PasswordResetUserSelection")
	}
	
}
