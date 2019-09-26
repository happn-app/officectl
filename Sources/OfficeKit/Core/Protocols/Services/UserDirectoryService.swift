/*
 * UserDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 22/05/2019.
 */

import Foundation

import Async
import GenericJSON
import Service



public protocol UserDirectoryService : OfficeKitService, UserDirectoryServiceInit {
	
	associatedtype UserType : DirectoryUser
	
	/** Convert the user to a user printable string. Mostly used for logging. */
	func shortDescription(fromUser user: UserType) -> String
	
	/** Empty ids are **not supported**. There are no other restrictions. */
	func string(fromUserId userId: UserType.IdType) -> String
	func userId(fromString string: String) throws -> UserType.IdType
	
	func string(fromPersistentUserId pId: UserType.PersistentIdType) -> String
	func persistentUserId(fromString string: String) throws -> UserType.PersistentIdType
	
	/**
	Converts the given user to a JSON (generic codable storage representation).
	
	The representation is usually used to store as an underlying user in a
	DirectoryUserWrapper. It should contain as much as possible from the original
	user. */
	func json(fromUser user: UserType) throws -> JSON
	
	/**
	If possible, converts the given generic user to a user for the service with
	as much information as possible.
	
	The conversion should not fetch anything from the directory. It is simply a
	representation of how the given id _should_ be created in the directory if it
	were to be created in it.
	
	Generally, the method implementation should first check the source service id
	of the given user (which is actually the tag of the tagged id of the wrapped
	user).
	If the user comes from your own service (the source service id of the user
	and your service id are equal), you should directly convert the underlying
	user of the given user (this is the equivalent of doing the reverse of
	`json(fromUser:)`).
	Otherwise (the user comes from an unknown service), you should apply custom
	rules to create a user from the generic properties available in the wrapped
	user.
	
	If the user wrapper has data that is inconsistent with the underlying user,
	the result of the method is undefined. Implementations can, but are not
	required to validate the user wrapper for consistency with its underlying
	user. */
	func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> UserType
	
	/** Returns the properties that were successfully applied to the user. */
	@discardableResult
	func applyHints(_ hints: [DirectoryUserProperty: String?], toUser user: inout UserType, allowUserIdChange: Bool) -> Set<DirectoryUserProperty>
	
	/**
	Fetch and return the _only_ user matching the given id.
	
	If _more than one_ user matches the given id, the function should return a
	**failed** future. If _no_ users match the given id, the method should
	return a succeeded future with a `nil` user. */
	func existingUser(fromPersistentId pId: UserType.PersistentIdType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?>
	/**
	Fetch and return the _only_ user matching the given id.
	
	If _more than one_ user matches the given id, the function should return a
	**failed** future. If _no_ users match the given id, the method should
	return a succeeded future with a `nil` user. */
	func existingUser(fromUserId uId: UserType.IdType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?>
	
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


extension UserDirectoryService {
	
	public func taggedId(fromUserId userId: UserType.IdType) -> TaggedId {
		return TaggedId(tag: config.serviceId, id: string(fromUserId: userId))
	}
	
	public func taggedId(fromPersistentUserId pId: UserType.PersistentIdType) -> TaggedId {
		return TaggedId(tag: config.serviceId, id: string(fromPersistentUserId: pId))
	}
	
	public func wrappedUser(fromUser user: UserType) throws -> DirectoryUserWrapper {
		var ret = DirectoryUserWrapper(
			userId: taggedId(fromUserId: user.userId),
			persistentId: user.persistentId.value.flatMap{ taggedId(fromPersistentUserId: $0) },
			underlyingUser: try json(fromUser: user)
		)
		ret.copyStandardNonIdProperties(fromUser: user)
		return ret
	}
	
	public func logicalUser(fromWrappedUser user: DirectoryUserWrapper, hints: [DirectoryUserProperty: String?]) throws -> UserType {
		var ret = try logicalUser(fromWrappedUser: user)
		applyHints(hints, toUser: &ret, allowUserIdChange: false)
		return ret
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: String?] = [:], servicesProvider: OfficeKitServiceProvider) throws -> UserType {
		return try logicalUser(fromEmail: email, hints: hints, emailService: servicesProvider.getUserDirectoryService(id: nil))
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: String?] = [:], emailService: EmailService) throws -> UserType {
		let genericUser = try emailService.wrappedUser(fromUser: emailService.logicalUser(fromUserId: email))
		return try logicalUser(fromWrappedUser: genericUser, hints: hints)
	}
	
	public func logicalUser(fromUserId userId: UserType.IdType, hints: [DirectoryUserProperty: String?] = [:]) throws -> UserType {
		let user = DirectoryUserWrapper(userId: taggedId(fromUserId: userId))
		return try logicalUser(fromWrappedUser: user, hints: hints)
	}
	
	public func logicalUser<OtherServiceType : UserDirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: String?] = [:]) throws -> UserType {
		return try logicalUser(fromWrappedUser: service.wrappedUser(fromUser: user), hints: hints)
	}
	
	public func existingUser<OtherServiceType : UserDirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?> {
		let foreignGenericUser = try service.wrappedUser(fromUser: user)
		let nativeLogicalUser = try logicalUser(fromWrappedUser: foreignGenericUser, hints: [:])
		return try existingUser(fromUserId: nativeLogicalUser.userId, propertiesToFetch: propertiesToFetch, on: container)
	}
	
}



/* **********************
   MARK: - Erasure Things
   ********************** */

public protocol UserDirectoryServiceInit {
	
	static var configType: OfficeKitServiceConfigInit.Type {get}
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig) -> AnyUserDirectoryService?
	
}

public extension UserDirectoryService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig) -> AnyUserDirectoryService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unboxed() else {return nil}
		return self.init(config: c, globalConfig: gc).erased()
	}
	
}
