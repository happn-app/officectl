/*
 * PasswordResetController.swift
 * officectl
 *
 * Created by François Lamboley on 09/08/2018.
 */

import Foundation

import Vapor

import OfficeKit



final class PasswordResetController {
	
	func showUserSelection(_ req: Request) throws -> Future<View> {
		return try req.view().render("PasswordResetUserSelection")
	}
	
	func showResetPage(_ req: Request) throws -> String {
		let emailStr = try req.parameters.next(String.self)
		
		/* Let’s validate the email */
		guard let email = Email(string: emailStr) else {throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid email"])}
		/* Only happn.fr domain supported for now */
		guard email.domain == "happn.fr" else {throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Only happn.fr emails are supported for now"])}
		/* Only “regular” username (no fancy characters are allowed) */
		let regex = try! NSRegularExpression(pattern: "[^0-9a-z_.-]", options: [])
		guard regex.firstMatch(in: email.username, options: [], range: NSRange(email.username.startIndex..<email.username.endIndex, in: email.username)) == nil else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid character in username"])
		}
		
		return emailStr
	}
	
}
