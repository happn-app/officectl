/*
 * Email+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 27/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



extension Email : Parameter {
	
	public static func resolveParameter(_ emailStr: String, on container: Container) throws -> Email {
		guard let email = Email(string: emailStr) else {
			throw BasicValidationError("Invalid email")
		}
		return email
	}
	
}
