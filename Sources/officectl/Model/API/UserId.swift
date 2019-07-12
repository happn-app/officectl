/*
 * UserId.swift
 * officectl
 *
 * Created by François Lamboley on 04/03/2019.
 */

import Foundation

import OfficeKit
import Vapor



struct UserId : Parameter {
	
	var service: AnyDirectoryService
	var id: AnyHashable
	
	public static func resolveParameter(_ parameter: String, on container: Container) throws -> UserId {
		return try UserId(string: parameter, container: container)
	}
	
	init(string: String, container: Container) throws {
		let taggedId = try TaggedId(string: string)
		
		service = try container.make(OfficeKitServiceProvider.self).getDirectoryService(id: taggedId.tag, container: container)
		id = try service.userId(from: taggedId.id)
	}
	
	var stringValue: String {
		assert(!service.config.serviceId.contains(":"))
		return service.config.serviceId + ":" + service.string(from: id)
	}
	
}
