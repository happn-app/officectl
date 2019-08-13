/*
 * FullUser.swift
 * officectl
 *
 * Created by François Lamboley on 12/08/2019.
 */

import Foundation

import OfficeKit
import Service



struct FullUser {
	
	let service: AnyDirectoryService
	let user: AnyDirectoryUser
	
	let fullUserId: FullUserId
	let taggedId: TaggedId
	
	init(fullUserId fuid: FullUserId) throws {
		service = fuid.service
		user = try service.logicalUser(fromUserId: fuid.id)
		
		fullUserId = fuid
		taggedId = fullUserId.taggedId
	}
	
	init(taggedId tid: TaggedId, container: Container) throws {
		let fullUserId = try FullUserId(taggedId: tid, container: container)
		try self.init(fullUserId: fullUserId)
	}
	
	init(string: String, container: Container) throws {
		try self.init(taggedId: TaggedId(string: string), container: container)
	}
	
}
