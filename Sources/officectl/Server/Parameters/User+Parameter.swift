/*
 * User+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 27/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



extension User : Parameter {
	
	public static func resolveParameter(_ emailStr: String, on container: Container) throws -> User {
		/* Let’s validate the email */
		guard let email = Email(string: emailStr).flatMap({ $0.domain == "happn.com" ? Email(username: $0.username, domain: "happn.fr") : $0 }) else {
			throw BasicValidationError("Invalid email")
		}
		/* Only happn.fr domain supported for now */
		guard email.domain == "happn.fr" else {throw BasicValidationError("Only happn.fr emails are supported for now")}
		/* Only “regular” username (no fancy characters are allowed) */
		let regex = try! NSRegularExpression(pattern: "[^0-9a-z_.-]", options: [])
		guard regex.firstMatch(in: email.username, options: [], range: NSRange(email.username.startIndex..<email.username.endIndex, in: email.username)) == nil else {
			throw BasicValidationError("Invalid character in username")
		}
		
		return User(id: .email(email))
	}
	
}
