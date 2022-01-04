/*
 * AnyUserDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/27.
 */

import Foundation

import GenericJSON
import NIO
import ServiceKit



private protocol UserDirectoryServiceBox {
	
	func unbox<T : UserDirectoryService>() -> T?
	
	func shortDescription(fromUser user: AnyDirectoryUser) -> String
	
	func string(fromUserID userID: AnyID) -> String
	func userID(fromString string: String) throws -> AnyID
	
	func string(fromPersistentUserID pID: AnyID) -> String
	func persistentUserID(fromString string: String) throws -> AnyID
	
	func json(fromUser user: AnyDirectoryUser) throws -> JSON
	func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> AnyDirectoryUser
	
	func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout AnyDirectoryUser, allowUserIDChange: Bool) -> Set<DirectoryUserProperty>
	
	func existingUser(fromPersistentID pID: AnyID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser?
	func existingUser(fromUserID uID: AnyID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser?
	
	func listAllUsers(using services: Services) async throws -> [AnyDirectoryUser]
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: AnyDirectoryUser, using services: Services) async throws -> AnyDirectoryUser
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: AnyDirectoryUser, using services: Services) async throws
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: AnyDirectoryUser, using services: Services) throws -> ResetPasswordAction
	
}

private struct ConcreteUserDirectoryBox<Base : UserDirectoryService> : UserDirectoryServiceBox {
	
	let originalDirectory: Base
	
	func unbox<T>() -> T? where T : UserDirectoryService {
		return originalDirectory as? T
	}
	
	func shortDescription(fromUser user: AnyDirectoryUser) -> String {
		guard let u: Base.UserType = user.unbox() else {
			return "UnknownAnyDirectoryUser<\(user)>"
		}
		return originalDirectory.shortDescription(fromUser: u)
	}
	
	func string(fromUserID userID: AnyID) -> String {
		guard let typedID: Base.UserType.IDType = userID.unbox() else {
			OfficeKitConfig.logger?.error("Asked to convert a user ID to a string for a user ID of unknown type in erasure: \(userID)")
			/* The source user type is unknown, so we return a purposefully invalid ID.
			 * This is not ideal… */
			return ""
		}
		return originalDirectory.string(fromUserID: typedID)
	}
	
	func userID(fromString string: String) throws -> AnyID {
		return try AnyID(originalDirectory.userID(fromString: string))
	}
	
	func string(fromPersistentUserID pID: AnyID) -> String {
		guard let typedID: Base.UserType.PersistentIDType = pID.unbox() else {
			OfficeKitConfig.logger?.error("Asked to convert a persistend ID to a string for a persistent ID of unknown type in erasure: \(pID)")
			/* The source user type is unknown, so we return a purposefully invalid ID.
			 * This is not ideal… */
			return ""
		}
		return originalDirectory.string(fromPersistentUserID: typedID)
	}
	
	func persistentUserID(fromString string: String) throws -> AnyID {
		return try AnyID(originalDirectory.persistentUserID(fromString: string))
	}
	
	func json(fromUser user: AnyDirectoryUser) throws -> JSON {
		guard let u: Base.UserType = user.unbox() else {
			throw InvalidArgumentError(message: "Got invalid user (\(user)) from which to create a JSON.")
		}
		return try originalDirectory.json(fromUser: u)
	}
	
	func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> AnyDirectoryUser {
		return try originalDirectory.logicalUser(fromWrappedUser: userWrapper).erase()
	}
	
	func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout AnyDirectoryUser, allowUserIDChange: Bool) -> Set<DirectoryUserProperty> {
		guard var u: Base.UserType = user.unbox() else {
			OfficeKitConfig.logger?.error("Asked to apply hints to a user of unknown type in erasure: \(user)")
			/* The source user type is unknown, so we do nothing. */
			return []
		}
		let ret = originalDirectory.applyHints(hints, toUser: &u, allowUserIDChange: allowUserIDChange)
		user = u.erase()
		return ret
	}
	
	func existingUser(fromPersistentID pID: AnyID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser? {
		guard let typedID: Base.UserType.PersistentIDType = pID.unbox() else {
			throw InvalidArgumentError(message: "Got invalid persistent user ID (\(pID)) for fetching user with directory service of type \(Base.self)")
		}
		return try await originalDirectory.existingUser(fromPersistentID: typedID, propertiesToFetch: propertiesToFetch, using: services)?.erase()
	}
	
	func existingUser(fromUserID uID: AnyID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser? {
		guard let typedID: Base.UserType.IDType = uID.unbox() else {
			throw InvalidArgumentError(message: "Got invalid user ID (\(uID)) for fetching user with directory service of type \(Base.self)")
		}
		return try await originalDirectory.existingUser(fromUserID: typedID, propertiesToFetch: propertiesToFetch, using: services)?.erase()
	}
	
	func listAllUsers(using services: Services) async throws -> [AnyDirectoryUser] {
		return try await originalDirectory.listAllUsers(using : services).map{ $0.erase() }
	}
	
	var supportsUserCreation: Bool {return originalDirectory.supportsUserCreation}
	func createUser(_ user: AnyDirectoryUser, using services: Services) async throws -> AnyDirectoryUser {
		guard let u: Base.UserType = user.unbox() else {
			throw InvalidArgumentError(message: "Got invalid user to create (\(user)) for directory service of type \(Base.self)")
		}
		return try await originalDirectory.createUser(u, using: services).erase()
	}
	
	var supportsUserUpdate: Bool {return originalDirectory.supportsUserUpdate}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser {
		guard let u: Base.UserType = user.unbox() else {
			throw InvalidArgumentError(message: "Got invalid user to update (\(user)) for directory service of type \(Base.self)")
		}
		return try await originalDirectory.updateUser(u, propertiesToUpdate: propertiesToUpdate, using: services).erase()
	}
	
	var supportsUserDeletion: Bool {return originalDirectory.supportsUserDeletion}
	func deleteUser(_ user: AnyDirectoryUser, using services: Services) async throws {
		guard let u: Base.UserType = user.unbox() else {
			throw InvalidArgumentError(message: "Got invalid user to delete (\(user)) for directory service of type \(Base.self)")
		}
		return try await originalDirectory.deleteUser(u, using: services)
	}
	
	var supportsPasswordChange: Bool {return originalDirectory.supportsPasswordChange}
	func changePasswordAction(for user: AnyDirectoryUser, using services: Services) throws -> ResetPasswordAction {
		guard let u: Base.UserType = user.unbox() else {
			throw InvalidArgumentError(message: "Got invalid user (\(user)) to retrieve password action for directory service of type \(Base.self)")
		}
		return try originalDirectory.changePasswordAction(for: u, using: services)
	}
	
}

public class AnyUserDirectoryService : AnyOfficeKitService, UserDirectoryService {
	
	public typealias UserType = AnyDirectoryUser
	
	override init<T : OfficeKitService>(s object: T) {
		fatalError()
	}
	
	init<T : UserDirectoryService>(uds object: T) {
		box = ConcreteUserDirectoryBox(originalDirectory: object)
		super.init(s: object)
	}
	
	public required init(config c: AnyOfficeKitServiceConfig, globalConfig gc: GlobalConfig) {
		fatalError("init(config:globalConfig:) unavailable for a directory service erasure")
	}
	
	public func shortDescription(fromUser user: AnyDirectoryUser) -> String {
		return box.shortDescription(fromUser: user)
	}
	
	public func string(fromUserID userID: AnyID) -> String {
		return box.string(fromUserID: userID)
	}
	
	public func userID(fromString string: String) throws -> AnyID {
		return try box.userID(fromString: string)
	}
	
	public func string(fromPersistentUserID pID: AnyID) -> String {
		return box.string(fromPersistentUserID: pID)
	}
	
	public func persistentUserID(fromString string: String) throws -> AnyID {
		return try box.persistentUserID(fromString: string)
	}
	
	public func json(fromUser user: AnyDirectoryUser) throws -> JSON {
		return try box.json(fromUser: user)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> AnyDirectoryUser {
		return try box.logicalUser(fromWrappedUser: userWrapper)
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout AnyDirectoryUser, allowUserIDChange: Bool) -> Set<DirectoryUserProperty> {
		return box.applyHints(hints, toUser: &user, allowUserIDChange: allowUserIDChange)
	}
	
	public func existingUser(fromPersistentID pID: AnyID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser? {
		return try await box.existingUser(fromPersistentID: pID, propertiesToFetch: propertiesToFetch, using: services)
	}
	
	public func existingUser(fromUserID uid: AnyID, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser? {
		return try await box.existingUser(fromUserID: uid, propertiesToFetch: propertiesToFetch, using: services)
	}
	
	public func listAllUsers(using services: Services) async throws -> [AnyDirectoryUser] {
		return try await box.listAllUsers(using: services)
	}
	
	public var supportsUserCreation: Bool {return box.supportsUserCreation}
	public func createUser(_ user: AnyDirectoryUser, using services: Services) async throws -> AnyDirectoryUser {
		return try await box.createUser(user, using: services)
	}
	
	public var supportsUserUpdate: Bool {return box.supportsUserUpdate}
	public func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> AnyDirectoryUser {
		return try await box.updateUser(user, propertiesToUpdate: propertiesToUpdate, using: services)
	}
	
	public var supportsUserDeletion: Bool {return box.supportsUserDeletion}
	public func deleteUser(_ user: AnyDirectoryUser, using services: Services) async throws {
		return try await box.deleteUser(user, using: services)
	}
	
	public var supportsPasswordChange: Bool {return box.supportsPasswordChange}
	public func changePasswordAction(for user: AnyDirectoryUser, using services: Services) throws -> ResetPasswordAction {
		return try box.changePasswordAction(for: user, using: services)
	}
	
	fileprivate let box: UserDirectoryServiceBox
	
}

extension UserDirectoryService {
	
	public func erase() -> AnyUserDirectoryService {
		if let erased = self as? AnyUserDirectoryService {
			return erased
		}
		
		return AnyUserDirectoryService(uds: self)
	}
	
	public func unbox<DirectoryType : UserDirectoryService>() -> DirectoryType? {
		guard let anyService = self as? AnyUserDirectoryService, !(DirectoryType.self is AnyUserDirectoryService.Type) else {
			/* Nothing to unbox, just return self */
			return self as? DirectoryType
		}
		
		return (anyService.box as? ConcreteUserDirectoryBox<DirectoryType>)?.originalDirectory ?? (anyService.box as? ConcreteUserDirectoryBox<AnyUserDirectoryService>)?.originalDirectory.unbox()
	}
	
}
