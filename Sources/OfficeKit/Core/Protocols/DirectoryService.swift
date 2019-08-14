/*
 * DirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 22/05/2019.
 */

import Foundation

import Async
import GenericJSON
import Service



public protocol DirectoryService : class {
	
	/** The id of the linked provider, e.g. "internal_openldap". Those are static
	in OfficeKit. */
	static var providerId: String {get}
	
	associatedtype ConfigType : OfficeKitServiceConfig
	associatedtype UserType : DirectoryUser
	
	var config: ConfigType {get}
	
	init(config c: ConfigType)
	
	/** Convert the user to a user printable string. Mostly used for logging. */
	func shortDescription(from user: UserType) -> String
	
	/** Empty ids are **not supported**. There are no other restrictions. */
	func string(fromUserId userId: UserType.UserIdType) -> String
	func userId(fromString string: String) throws -> UserType.UserIdType
	
	func string(fromPersistentId pId: UserType.PersistentIdType) -> String
	func persistentId(fromString string: String) throws -> UserType.PersistentIdType
	
	/**
	Converts the given user to a JSON (generic codable storage representation).
	
	The representation is usually used to store as an underlying user in a
	DirectoryUserWrapper. It should contain as much as possible from the original
	user.
	
	Note: We might want to make this a non-throwable func… */
	func json(fromUser user: UserType) throws -> JSON
	
	/** If possible, convert the given generic user to a user with as much
	information as possible in your directory.
	
	The conversion should not fetch anything from the directory. It is simply a
	representation of how the given id _should_ be created in the directory if it
	were to be created in it. */
	func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> UserType
	
	/** Fetch and return the _only_ user matching the given id.
	
	If _more than one_ user matches the given id, the function should return a
	**failed** future. If _no_ users match the given id, the method should
	return a succeeded future with a `nil` user. */
	func existingUser(fromPersistentId pId: UserType.PersistentIdType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?>
	/** Fetch and return the _only_ user matching the given id.
	
	If _more than one_ user matches the given id, the function should return a
	**failed** future. If _no_ users match the given id, the method should
	return a succeeded future with a `nil` user. */
	func existingUser(fromUserId uId: UserType.UserIdType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?>
	
	func listAllUsers(on container: Container) throws -> Future<[UserType]>
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: UserType, on container: Container) throws -> Future<UserType>
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: UserType, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType>
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: UserType, on container: Container) throws -> Future<Void>
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: UserType, on container: Container) throws -> ResetPasswordAction
	
}


extension DirectoryService {
	
	public func taggedId(fromUserId userId: UserType.UserIdType) -> TaggedId {
		return TaggedId(tag: config.serviceId, id: string(fromUserId: userId))
	}
	
	public func taggedId(fromPersistentId pId: UserType.PersistentIdType) -> TaggedId {
		return TaggedId(tag: config.serviceId, id: string(fromPersistentId: pId))
	}
	
	public func wrappedUser(fromUser user: UserType) throws -> DirectoryUserWrapper {
		var ret = DirectoryUserWrapper(
			userId: taggedId(fromUserId: user.userId),
			persistentId: user.persistentId.value.flatMap{ taggedId(fromPersistentId: $0) },
			underlyingUser: try json(fromUser: user)
		)
		ret.copyStandardNonIdProperties(fromUser: user)
		return ret
	}
	
	public func wrappedUser(fromUserId userId: UserType.UserIdType) -> DirectoryUserWrapper {
		return DirectoryUserWrapper(userId: taggedId(fromUserId: userId))
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any?] = [:]) throws -> UserType {
		var genericUser = DirectoryUserWrapper(email: email)
		genericUser.applyHints(hints)
		return try logicalUser(fromWrappedUser: genericUser)
	}
	
	public func logicalUser(fromUserId userId: UserType.UserIdType, hints: [DirectoryUserProperty: Any?] = [:]) throws -> UserType {
		var user = wrappedUser(fromUserId: userId)
		user.applyHints(hints)
		return try logicalUser(fromWrappedUser: user)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any?] = [:]) throws -> UserType {
		var genericUser = try service.wrappedUser(fromUser: user)
		genericUser.applyHints(hints)
		return try logicalUser(fromWrappedUser: genericUser)
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?> {
		let foreignGenericUser = try service.wrappedUser(fromUser: user)
		let nativeLogicalUser = try logicalUser(fromWrappedUser: foreignGenericUser)
		return try existingUser(fromUserId: nativeLogicalUser.userId, propertiesToFetch: propertiesToFetch, on: container)
	}
	
}
