/*
 * FullUserId.swift
 * officectl
 *
 * Created by François Lamboley on 12/08/2019.
 */

import Foundation

import OfficeKit
import Vapor



struct FullUserId {
	
	let service: AnyDirectoryService
	let id: AnyHashable
	
	let taggedId: TaggedId
	
	init(taggedId tid: TaggedId, container: Container) throws {
		service = try container.make(OfficeKitServiceProvider.self).getDirectoryService(id: tid.tag, container: container)
		id = try service.userId(fromString: tid.id)
		taggedId = tid
	}
	
	init(string: String, container: Container) throws {
		let tid = try TaggedId(string: string)
		try self.init(taggedId: tid, container: container)
	}
	
}
