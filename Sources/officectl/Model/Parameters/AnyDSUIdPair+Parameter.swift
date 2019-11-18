/*
 * FullUserId+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 12/08/2019.
 */

import Foundation

import OfficeKit
import Vapor



extension AnyDSUIdPair {
	
	public static func getAsParameter(named parameterName: String, from request: Request) throws -> AnyDSUIdPair {
		let str = try nil2throw(request.parameters.get(parameterName))
		return try AnyDSUIdPair(string: str, servicesProvider: request.make())
	}
	
}
