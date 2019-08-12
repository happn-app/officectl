/*
 * FullUserId+Parameter.swift
 * officectl
 *
 * Created by François Lamboley on 12/08/2019.
 */

import Foundation

import OfficeKit
import Vapor



extension FullUserId : Parameter {
	
	public typealias ResolvedParameter = FullUserId
	
	public static func resolveParameter(_ parameter: String, on container: Container) throws -> FullUserId {
		return try FullUserId(string: parameter, container: container)
	}
	
}
