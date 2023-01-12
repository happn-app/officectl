/*
 * Email+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 2018/08/27.
 */

import Foundation

import Email
import OfficeKit
import UnwrapOrThrow
import Vapor



extension Email {
	
	public static func getAsParameter(named parameterName: String, from request: Request) throws -> Email {
		let str = try request.parameters.get(parameterName) ?! MissingFieldError(parameterName)
		guard let email = Email(rawValue: str) else {
			throw InvalidArgumentError(message: "Invalid email")
		}
		return email
	}
	
}
