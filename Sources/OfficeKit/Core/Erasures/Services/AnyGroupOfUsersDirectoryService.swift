/*
 * AnyGroupOfUsersDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/09/2019.
 */

import Foundation

import GenericJSON
import NIO
import ServiceKit



private protocol GroupOfUsersDirectoryServiceBox {
	
	func unbox<T : GroupOfUsersDirectoryService>() -> T?
	
	func shortDescription(fromGroup group: AnyDirectoryGroup) -> String
	
	func listUsers(inGroup group: AnyDirectoryGroup, using services: Services) async throws -> [AnyDirectoryUser]
	func listGroups(withUser user: AnyDirectoryUser, using services: Services) async throws -> [AnyDirectoryGroup]
	
	var supportsEmbeddedGroupsOfUsers: Bool {get}
	func listGroups(inGroup group: AnyDirectoryGroup, using services: Services) async throws -> [AnyDirectoryGroup]
	
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
	
	func listUsers(inGroup group: AnyDirectoryGroup, using services: Services) async throws -> [AnyDirectoryUser] {
		guard let g: Base.GroupType = group.unbox() else {
			throw InvalidArgumentError(message: "Got invalid group (\(group)) from which to list users in.")
		}
		return try await originalDirectory.listUsers(inGroup: g, using: services).map{ AnyDirectoryUser($0) }
	}
	
	func listGroups(withUser user: AnyDirectoryUser, using services: Services) async throws -> [AnyDirectoryGroup] {
		guard let u: Base.UserType = user.unbox() else {
			throw InvalidArgumentError(message: "Got invalid user (\(user)) for which to list groups that contains it.")
		}
		return try await originalDirectory.listGroups(withUser: u, using: services).map{ AnyDirectoryGroup($0) }
	}
	
	var supportsEmbeddedGroupsOfUsers: Bool {
		return originalDirectory.supportsEmbeddedGroupsOfUsers
	}
	
	func listGroups(inGroup group: AnyDirectoryGroup, using services: Services) async throws -> [AnyDirectoryGroup] {
		guard let g: Base.GroupType = group.unbox() else {
			throw InvalidArgumentError(message: "Got invalid group (\(group)) from which to list users in.")
		}
		return try await originalDirectory.listGroups(inGroup: g, using: services).map{ AnyDirectoryGroup($0) }
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
	
	public func listUsers(inGroup group: AnyDirectoryGroup, using services: Services) async throws -> [AnyDirectoryUser] {
		return try await box.listUsers(inGroup: group, using: services)
	}
	
	public func listGroups(withUser user: AnyDirectoryUser, using services: Services) async throws -> [AnyDirectoryGroup] {
		return try await box.listGroups(withUser: user, using: services)
	}
	
	public var supportsEmbeddedGroupsOfUsers: Bool {
		return box.supportsEmbeddedGroupsOfUsers
	}
	
	public func listGroups(inGroup group: AnyDirectoryGroup, using services: Services) async throws -> [AnyDirectoryGroup] {
		return try await box.listGroups(inGroup: group, using: services)
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
