/*
 * AnyDSUIdPair+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 2019/08/12.
 */

import Foundation

import OfficeKit
import UnwrapOrThrow
import Vapor



extension AnyDSUIDPair {
	
	public static func getAsParameter(named parameterName: String, from request: Request) throws -> AnyDSUIDPair {
		let str = try request.parameters.get(parameterName) ?! MissingFieldError(parameterName)
		return try AnyDSUIDPair(string: str, servicesProvider: request.application.officeKitServiceProvider)
	}
	
}
