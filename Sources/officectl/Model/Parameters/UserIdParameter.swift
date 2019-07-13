/*
 * UserIdParameter.swift
 * officectl
 *
 * Created by François Lamboley on 04/03/2019.
 */

import Foundation

import OfficeKit
import Vapor



struct UserIdParameter : Parameter {
	
	var service: AnyDirectoryService
	var id: AnyHashable
	
	static func resolveParameter(_ parameter: String, on container: Container) throws -> UserIdParameter {
		return try UserIdParameter(string: parameter, container: container)
	}
	
	init(taggedId: TaggedId, container: Container) throws {
		service = try container.make(OfficeKitServiceProvider.self).getDirectoryService(id: taggedId.tag, container: container)
		id = try service.userId(fromString: taggedId.id)
	}
	
	init(string: String, container: Container) throws {
		let taggedId = try TaggedId(string: string)
		try self.init(taggedId: taggedId, container: container)
	}
	
	var taggedId: TaggedId {
		assert(!service.config.serviceId.contains(":"))
		return TaggedId(tag: service.config.serviceId, id: service.string(fromUserId: id))
	}
	
}
