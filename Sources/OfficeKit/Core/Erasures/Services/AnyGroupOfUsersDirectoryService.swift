/*
 * AnyGroupOfUsersDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/09/2019.
 */

import Foundation

import Async
import GenericJSON
import Service



private protocol GroupOfUsersDirectoryServiceBox {
	
	func unbox<T : GroupOfUsersDirectoryService>() -> T?
	
	func shortDescription(fromGroup group: AnyDirectoryGroup) -> String
	
	func listUsers(inGroup group: AnyDirectoryGroup, on container: Container) throws -> EventLoopFuture<[AnyDirectoryUser]>
	
	var supportsEmbeddedGroupsOfUsers: Bool {get}
	func listGroups(inGroup group: AnyDirectoryGroup, on container: Container) throws -> EventLoopFuture<[AnyDirectoryGroup]>
	
}

private struct ConcreteGroupOfUsersDirectoryServiceBox<Base : GroupOfUsersDirectoryService> : GroupOfUsersDirectoryServiceBox {
	
	let originalDirectory: Base
	
	func unbox<T>() -> T? where T : GroupOfUsersDirectoryService {
		return originalDirectory as? T
	}
	
	func shortDescription(fromGroup group: AnyDirectoryGroup) -> String {
		guard let g: Base.GroupType = group.unbox() else {
			return "UnknownAnyDirectoryGroupOfUsers<\(group)>"
		}
		return originalDirectory.shortDescription(fromGroup: g)
	}
	
	func listUsers(inGroup group: AnyDirectoryGroup, on container: Container) throws -> EventLoopFuture<[AnyDirectoryUser]> {
		guard let g: Base.GroupType = group.unbox() else {
			throw InvalidArgumentError(message: "Got invalid group (\(group)) from which to list users in.")
		}
		return try originalDirectory.listUsers(inGroup: g, on: container).map{ $0.map{ AnyDirectoryUser($0) } }
	}
	
	var supportsEmbeddedGroupsOfUsers: Bool {
		return originalDirectory.supportsEmbeddedGroupsOfUsers
	}
	
	func listGroups(inGroup group: AnyDirectoryGroup, on container: Container) throws -> EventLoopFuture<[AnyDirectoryGroup]> {
		guard let g: Base.GroupType = group.unbox() else {
			throw InvalidArgumentError(message: "Got invalid group (\(group)) from which to list users in.")
		}
		return try originalDirectory.listGroups(inGroup: g, on: container).map{ $0.map{ AnyDirectoryGroup($0) } }
	}
	
}

public class AnyGroupOfUsersDirectoryService : AnyUserDirectoryService, GroupOfUsersDirectoryService {
	
	public typealias GroupType = AnyDirectoryGroup
	
	override init<T : UserDirectoryService>(uds object: T) {
		fatalError()
	}
	
	init<T : GroupOfUsersDirectoryService>(gouds object: T) {
		box = ConcreteGroupOfUsersDirectoryServiceBox(originalDirectory: object)
		super.init(uds: object)
	}
	
	public required init(config c: AnyOfficeKitServiceConfig, globalConfig gc: GlobalConfig) {
		fatalError("init(config:globalConfig:) unavailable for a directory service erasure")
	}
	
	public func shortDescription(fromGroup group: AnyGroupOfUsersDirectoryService.GroupType) -> String {
		return box.shortDescription(fromGroup: group)
	}
	
	public func listUsers(inGroup group: AnyDirectoryGroup, on container: Container) throws -> EventLoopFuture<[AnyDirectoryUser]> {
		return try box.listUsers(inGroup: group, on: container)
	}
	
	public var supportsEmbeddedGroupsOfUsers: Bool {
		return box.supportsEmbeddedGroupsOfUsers
	}
	
	public func listGroups(inGroup group: AnyDirectoryGroup, on container: Container) throws -> EventLoopFuture<[AnyDirectoryGroup]> {
		return try box.listGroups(inGroup: group, on: container)
	}
	
	fileprivate let box: GroupOfUsersDirectoryServiceBox
	
}

extension GroupOfUsersDirectoryService {
	
	public func erase() -> AnyGroupOfUsersDirectoryService {
		if let erased = self as? AnyGroupOfUsersDirectoryService {
			return erased
		}
		
		return AnyGroupOfUsersDirectoryService(gouds: self)
	}
	
	public func unbox<DirectoryType : GroupOfUsersDirectoryService>() -> DirectoryType? {
		guard let anyService = self as? AnyGroupOfUsersDirectoryService, !(DirectoryType.self is AnyGroupOfUsersDirectoryService.Type) else {
			/* Nothing to unbox, just return self */
			return self as? DirectoryType
		}
		
		return (anyService.box as? ConcreteGroupOfUsersDirectoryServiceBox<DirectoryType>)?.originalDirectory ?? (anyService.box as? ConcreteGroupOfUsersDirectoryServiceBox<AnyGroupOfUsersDirectoryService>)?.originalDirectory.unbox()
	}
	
}
