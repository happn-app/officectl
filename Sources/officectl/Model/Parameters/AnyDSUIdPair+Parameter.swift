/*
 * FullUserId+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 12/08/2019.
 */

import Foundation

import OfficeKit
import Vapor



extension AnyDSUIdPair : Parameter {
	
	public typealias ResolvedParameter = AnyDSUIdPair
	
	public static func resolveParameter(_ parameter: String, on container: Container) throws -> AnyDSUIdPair {
		return try AnyDSUIdPair(string: parameter, servicesProvider: container.make())
	}
	
}
