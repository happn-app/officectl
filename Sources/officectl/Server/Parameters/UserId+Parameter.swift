/*
 * LDAPDistinguishedName+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 04/03/2019.
 */

import Foundation

import OfficeKit
import Vapor



extension UserId : Parameter {
	
	public static func resolveParameter(_ parameter: String, on container: Container) throws -> UserId {
		/* Let’s validate the user id */
		guard let id = try? UserId(string: parameter) else {
			throw BasicValidationError("Invalid user id")
		}
		return id
	}
	
}
