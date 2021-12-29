/*
 * FullUserId+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 2019/08/12.
 */

import Foundation

import OfficeKit
import Vapor



extension AnyDSUIdPair {
	
	public static func getAsParameter(named parameterName: String, from request: Request) throws -> AnyDSUIdPair {
		let str = try nil2throw(request.parameters.get(parameterName))
		return try AnyDSUIdPair(string: str, servicesProvider: request.application.officeKitServiceProvider)
	}
	
}
