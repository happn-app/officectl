/*
 * AnyDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 27/06/2019.
 */

import Foundation

import Async
import GenericJSON
import Service



private protocol DirectoryServiceBox {
	
	/* *** Hashable *** */
	
	func unbox<T : DirectoryService>() -> T?
	
	func hash(into hasher: inout Hasher)
	func isEqual(_ other: DirectoryServiceBox) -> Bool
	
	/* *** DirectoryService *** */
	
	var config: AnyOfficeKitServiceConfig {get}
	var globalConfig: GlobalConfig {get}
	
	func shortDescription(from user: AnyDirectoryUser) -> String
	
	func string(fromUserId userId: AnyDirectoryUserId) -> String
	func userId(fromString string: String) throws -> AnyDirectoryUserId
	
	func string(fromPersistentId pId: AnyDirectoryUserId) -> String
	func persistentId(fromString string: String) throws -> AnyDirectoryUserId
	
	func json(fromUser user: AnyDirectoryUser) throws -> JSON
	func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> AnyDirectoryUser
	
	func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout AnyDirectoryUser, allowUserIdChange: Bool) -> Set<DirectoryUserProperty>
	
	func existingUser(fromPersistentId pId: AnyDirectoryUserId, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?>
	func existingUser(fromUserId uId: AnyDirectoryUserId, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?>
	
	func listAllUsers(on container: Container) throws -> Future<[AnyDirectoryUser]>
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<AnyDirectoryUser>
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser>
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<Void>
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: AnyDirectoryUser, on container: Container) throws -> ResetPasswordAction
	
}

private struct ConcreteDirectoryBox<Base : DirectoryService> : DirectoryServiceBox {
	
	let originalDirectory: Base
	
	func unbox<T>() -> T? where T : DirectoryService {
		return originalDirectory as? T
	}
	
	func hash(into hasher: inout Hasher) {
		originalDirectory.hash(into: &hasher)
	}
	
	func isEqual(_ other: DirectoryServiceBox) -> Bool {
		guard let otherAsBase: Base = other.unbox() else {return false}
		return otherAsBase == originalDirectory
	}
	
	var config: AnyOfficeKitServiceConfig {
		return originalDirectory.config.erased()
	}
	
	var globalConfig: GlobalConfig {
		return originalDirectory.globalConfig
	}
	
	func shortDescription(from user: AnyDirectoryUser) -> String {
		guard let u: Base.UserType = user.unboxed() else {
			return "UnknownAnyDirectoryUser<\(user)>"
		}
		return originalDirectory.shortDescription(from: u)
	}
	
	func string(fromUserId userId: AnyDirectoryUserId) -> String {
		guard let typedId: Base.UserType.UserIdType = userId.unboxed() else {
			OfficeKitConfig.logger?.error("Asked to convert a user id to a string for a user id of unknown type in erasure: \(userId)")
			/* The source user type is unknown, so we return a purposefully invalid
			 * id. This is not ideal… */
			return ""
		}
		return originalDirectory.string(fromUserId: typedId)
	}
	
	func userId(fromString string: String) throws -> AnyDirectoryUserId {
		return try AnyDirectoryUserId(originalDirectory.userId(fromString: string))
	}
	
	func string(fromPersistentId pId: AnyDirectoryUserId) -> String {
		guard let typedId: Base.UserType.PersistentIdType = pId.unboxed() else {
			OfficeKitConfig.logger?.error("Asked to convert a persistend id to a string for a persistent id of unknown type in erasure: \(pId)")
			/* The source user type is unknown, so we return a purposefully invalid
			 * id. This is not ideal… */
			return ""
		}
		return originalDirectory.string(fromPersistentId: typedId)
	}
	
	func persistentId(fromString string: String) throws -> AnyDirectoryUserId {
		return try AnyDirectoryUserId(originalDirectory.persistentId(fromString: string))
	}
	
	func json(fromUser user: AnyDirectoryUser) throws -> JSON {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user (\(user)) from which to create a JSON.")
		}
		return try originalDirectory.json(fromUser: u)
	}
	
	func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> AnyDirectoryUser {
		return try originalDirectory.logicalUser(fromWrappedUser: userWrapper).erased()
	}
	
	func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout AnyDirectoryUser, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		guard var u: Base.UserType = user.unboxed() else {
			OfficeKitConfig.logger?.error("Asked to apply hints to a user of unknown type in erasure: \(user)")
			/* The source user type is unknown, so we do nothing. */
			return []
		}
		let ret = originalDirectory.applyHints(hints, toUser: &u, allowUserIdChange: allowUserIdChange)
		user = u.erased()
		return ret
	}
	
	func existingUser(fromPersistentId pId: AnyDirectoryUserId, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		guard let typedId: Base.UserType.PersistentIdType = pId.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid persistent user id (\(pId)) for fetching user with directory service of type \(Base.self)")
		}
		return try originalDirectory.existingUser(fromPersistentId: typedId, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
	}
	
	func existingUser(fromUserId uId: AnyDirectoryUserId, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		guard let typedId: Base.UserType.UserIdType = uId.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user id (\(uId)) for fetching user with directory service of type \(Base.self)")
		}
		return try originalDirectory.existingUser(fromUserId: typedId, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
	}
	
	func listAllUsers(on container: Container) throws -> Future<[AnyDirectoryUser]> {
		return try originalDirectory.listAllUsers(on : container).map{ $0.map{ $0.erased() } }
	}
	
	var supportsUserCreation: Bool {return originalDirectory.supportsUserCreation}
	func createUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<AnyDirectoryUser> {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user to create (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.createUser(u, on: container).map{ $0.erased() }
	}
	
	var supportsUserUpdate: Bool {return originalDirectory.supportsUserUpdate}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser> {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user to update (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.updateUser(u, propertiesToUpdate: propertiesToUpdate, on: container).map{ $0.erased() }
	}
	
	var supportsUserDeletion: Bool {return originalDirectory.supportsUserDeletion}
	func deleteUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<Void> {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user to delete (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.deleteUser(u, on: container)
	}
	
	var supportsPasswordChange: Bool {return originalDirectory.supportsPasswordChange}
	func changePasswordAction(for user: AnyDirectoryUser, on container: Container) throws -> ResetPasswordAction {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user (\(user)) to retrieve password action for directory service of type \(Base.self)")
		}
		return try originalDirectory.changePasswordAction(for: u, on: container)
	}
	
}

public class AnyDirectoryService : DirectoryService {
	
	public static var providerId: String {
		assertionFailure("Please do not use providerId on AnyDirectoryService. This is an erasure for a concrete DirectoryService type.")
		return "__OfficeKitInternal_OfficeKitServiceConfig_Erasure__"
	}
	
	public typealias ConfigType = AnyOfficeKitServiceConfig
	public typealias UserType = AnyDirectoryUser
	
	init<T : DirectoryService>(_ object: T) {
		box = ConcreteDirectoryBox(originalDirectory: object)
	}
	
	public required init(config c: AnyOfficeKitServiceConfig, globalConfig gc: GlobalConfig) {
		fatalError("init(config:globalConfig:) unavailable for a directory service erasure")
	}
	
	public func hash(into hasher: inout Hasher) {
		box.hash(into: &hasher)
	}
	
	public static func ==(_ lhs: AnyDirectoryService, _ rhs: AnyDirectoryService) -> Bool {
		return lhs.box.isEqual(rhs.box)
	}
	
	public var config: AnyOfficeKitServiceConfig {
		return box.config
	}
	
	public var globalConfig: GlobalConfig {
		return box.globalConfig
	}
	
	public func shortDescription(from user: AnyDirectoryUser) -> String {
		return box.shortDescription(from: user)
	}
	
	public func string(fromUserId userId: AnyDirectoryUserId) -> String {
		return box.string(fromUserId: userId)
	}
	
	public func userId(fromString string: String) throws -> AnyDirectoryUserId {
		return try box.userId(fromString: string)
	}
	
	public func string(fromPersistentId pId: AnyDirectoryUserId) -> String {
		return box.string(fromPersistentId: pId)
	}
	
	public func persistentId(fromString string: String) throws -> AnyDirectoryUserId {
		return try box.persistentId(fromString: string)
	}
	
	public func json(fromUser user: AnyDirectoryUser) throws -> JSON {
		return try box.json(fromUser: user)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> AnyDirectoryUser {
		return try box.logicalUser(fromWrappedUser: userWrapper)
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout AnyDirectoryUser, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		return box.applyHints(hints, toUser: &user, allowUserIdChange: allowUserIdChange)
	}
	
	public func existingUser(fromPersistentId pId: AnyDirectoryUserId, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try box.existingUser(fromPersistentId: pId, propertiesToFetch: propertiesToFetch, on: container)
	}
	
	public func existingUser(fromUserId uId: AnyDirectoryUserId, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try box.existingUser(fromUserId: uId, propertiesToFetch: propertiesToFetch, on: container)
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[AnyDirectoryUser]> {
		return try box.listAllUsers(on: container)
	}
	
	public var supportsUserCreation: Bool {return box.supportsUserCreation}
	public func createUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<AnyDirectoryUser> {
		return try box.createUser(user, on: container)
	}
	
	public var supportsUserUpdate: Bool {return box.supportsUserUpdate}
	public func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser> {
		return try box.updateUser(user, propertiesToUpdate: propertiesToUpdate, on: container)
	}
	
	public var supportsUserDeletion: Bool {return box.supportsUserDeletion}
	public func deleteUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<Void> {
		return try box.deleteUser(user, on: container)
	}
	
	public var supportsPasswordChange: Bool {return box.supportsPasswordChange}
	public func changePasswordAction(for user: AnyDirectoryUser, on container: Container) throws -> ResetPasswordAction {
		return try box.changePasswordAction(for: user, on: container)
	}
	
	fileprivate let box: DirectoryServiceBox
	
}

extension DirectoryService {
	
	public func erased() -> AnyDirectoryService {
		if let erased = self as? AnyDirectoryService {
			return erased
		}
		
		return AnyDirectoryService(self)
	}
	
	public func unboxed<DirectoryType : DirectoryService>() -> DirectoryType? {
		guard let anyService = self as? AnyDirectoryService else {
			/* Nothing to unbox, just return self */
			return self as? DirectoryType
		}
		
		return (anyService.box as? ConcreteDirectoryBox<DirectoryType>)?.originalDirectory ?? (anyService.box as? ConcreteDirectoryBox<AnyDirectoryService>)?.originalDirectory.unboxed()
	}
	
}
