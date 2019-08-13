/*
 * DirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 22/05/2019.
 */

import Foundation

import Async
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
	
	/**
	Converts the given user to a GenericDirectoryUser.
	
	This representation can be used to create native users for other services. It
	should contain everything it can from the original user. */
	func genericUser(fromUser user: UserType) throws -> GenericDirectoryUser
	
	/** If possible, convert the given generic user to a user with as much
	information as possible in your directory.
	
	The conversion should not fetch anything from the directory. It is simply a
	representation of how the given id _should_ be created in the directory if it
	were to be created in it. */
	func logicalUser(fromGenericUser genericUser: GenericDirectoryUser) throws -> UserType
	
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
	
	public func genericUser(fromUserId userId: UserType.UserIdType) -> GenericDirectoryUser {
		return GenericDirectoryUser(userId: taggedId(fromUserId: userId))
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any?] = [:]) throws -> UserType {
		var genericUser = GenericDirectoryUser(email: email)
		genericUser.applyHints(hints)
		return try logicalUser(fromGenericUser: genericUser)
	}
	
	public func logicalUser(fromUserId userId: UserType.UserIdType, hints: [DirectoryUserProperty: Any?] = [:]) throws -> UserType {
		var user = genericUser(fromUserId: userId)
		user.applyHints(hints)
		return try logicalUser(fromGenericUser: user)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any?] = [:]) throws -> UserType {
		var genericUser = try service.genericUser(fromUser: user)
		genericUser.applyHints(hints)
		return try logicalUser(fromGenericUser: genericUser)
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?> {
		let foreignGenericUser = try service.genericUser(fromUser: user)
		let nativeLogicalUser = try logicalUser(fromGenericUser: foreignGenericUser)
		return try existingUser(fromUserId: nativeLogicalUser.userId, propertiesToFetch: propertiesToFetch, on: container)
	}
	
}
