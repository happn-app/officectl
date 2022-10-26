/*
 * UserDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/05/22.
 */

import Foundation

import Email
import GenericJSON
import NIO
import ServiceKit

import OfficeModel



public protocol UserDirectoryService : OfficeKitService, UserDirectoryServiceInit, Sendable {
	
	associatedtype UserType : DirectoryUser
	
	/** Convert the user to a user printable string. Mostly used for logging. */
	func shortDescription(fromUser user: UserType) -> String
	
	/** Empty IDs are **not supported**. There are no other restrictions. */
	func string(fromUserID userID: UserType.IDType) -> String
	func userID(fromString string: String) throws -> UserType.IDType
	
	func string(fromPersistentUserID pID: UserType.PersistentIDType) -> String
	func persistentUserID(fromString string: String) throws -> UserType.PersistentIDType
	
	/**
	 Converts the given user to a JSON (generic codable storage representation).
	 
	 The representation is usually used to store as an underlying user in a DirectoryUserWrapper.
	 It should contain as much as possible from the original user. */
	func json(fromUser user: UserType) throws -> JSON
	
	/**
	 If possible, converts the given generic user to a user for the service with as much information as possible.
	 
	 The conversion should not fetch anything from the directory.
	 It is simply a representation of how the given ID _should_ be created in the directory if it were to be created in it.
	 
	 Generally, the method implementation should first check the source service ID of the given user
	 (which is actually the tag of the tagged ID of the wrapped user).
	 If the user comes from your own service (the source service ID of the user and your service ID are equal),
	 you should directly convert the underlying user of the given user (this is the equivalent of doing the reverse of `json(fromUser:)`).
	 Otherwise (the user comes from an unknown service), you should apply custom rules to create a user from the generic properties available in the wrapped user.
	 
	 If the user wrapper has data that is inconsistent with the underlying user, the result of the method is undefined.
	 Implementations can, but are not required to validate the user wrapper for consistency with its underlying user.
	 
	 This method should throw ``Err.cannotCreateLogicalUserFromWrappedUser`` if the conversion is not possible for the given wrapped user (e.g. missing info to compute the id of the user). */
	func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> UserType
	
	/** Returns the properties that were successfully applied to the user. */
	@discardableResult
	func applyHints(_ hints: [DirectoryUserProperty: String?], toUser user: inout UserType, allowUserIDChange: Bool) -> Set<DirectoryUserProperty>
	
	/**
	 Fetch and return the _only_ user matching the given ID.
	 
	 If _more than one_ user matches the given ID, the function should return a **failed** future.
	 If _no_ users match the given ID, the method should return a succeeded future with a `nil` user. */
	func existingUser(fromPersistentID pID: UserType.PersistentIDType, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> UserType?
	/**
	 Fetch and return the _only_ user matching the given ID.
	 
	 If _more than one_ user matches the given ID, the function should return a **failed** future.
	 If _no_ users match the given ID, the method should return a succeeded future with a `nil` user. */
	func existingUser(fromUserID uID: UserType.IDType, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> UserType?
	
	func listAllUsers(using services: Services) async throws -> [UserType]
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: UserType, using services: Services) async throws -> UserType
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: UserType, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> UserType
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: UserType, using services: Services) async throws
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: UserType, using services: Services) throws -> ResetPasswordAction
	
}


extension UserDirectoryService {
	
	public func taggedID(fromUserID userID: UserType.IDType) -> TaggedID {
		return TaggedID(tag: config.serviceID, id: string(fromUserID: userID))
	}
	
	public func taggedID(fromPersistentUserID pID: UserType.PersistentIDType) -> TaggedID {
		return TaggedID(tag: config.serviceID, id: string(fromPersistentUserID: pID))
	}
	
	public func wrappedUser(fromUser user: UserType) throws -> DirectoryUserWrapper {
		var ret = DirectoryUserWrapper(
			userID: taggedID(fromUserID: user.userID),
			persistentID: user.persistentID.flatMap{ taggedID(fromPersistentUserID: $0) },
			underlyingUser: try json(fromUser: user)
		)
		ret.copyStandardNonIDProperties(fromUser: user)
		return ret
	}
	
	public func logicalUser(fromWrappedUser user: DirectoryUserWrapper, hints: [DirectoryUserProperty: String?]) throws -> UserType {
		var ret = try logicalUser(fromWrappedUser: user)
		applyHints(hints, toUser: &ret, allowUserIDChange: false)
		return ret
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: String?] = [:], servicesProvider: OfficeKitServiceProvider) throws -> UserType {
		return try logicalUser(fromEmail: email, hints: hints, emailService: servicesProvider.getUserDirectoryService(id: nil))
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: String?] = [:], emailService: EmailService) throws -> UserType {
		let genericUser = try emailService.wrappedUser(fromUser: emailService.logicalUser(fromUserID: email))
		return try logicalUser(fromWrappedUser: genericUser, hints: hints)
	}
	
	public func logicalUser(fromUserID userID: UserType.IDType, hints: [DirectoryUserProperty: String?] = [:]) throws -> UserType {
		let user = DirectoryUserWrapper(userID: taggedID(fromUserID: userID))
		return try logicalUser(fromWrappedUser: user, hints: hints)
	}
	
	public func logicalUser<OtherServiceType : UserDirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: String?] = [:]) throws -> UserType {
		return try logicalUser(fromWrappedUser: service.wrappedUser(fromUser: user), hints: hints)
	}
	
	public func existingUser<OtherServiceType : UserDirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> UserType? {
		let foreignGenericUser = try service.wrappedUser(fromUser: user)
		let nativeLogicalUser = try logicalUser(fromWrappedUser: foreignGenericUser, hints: [:])
		return try await existingUser(fromUserID: nativeLogicalUser.userID, propertiesToFetch: propertiesToFetch, using: services)
	}
	
}



/* **********************
   MARK: - Erasure Things
   ********************** */

public protocol UserDirectoryServiceInit {
	
	static var configType: OfficeKitServiceConfigInit.Type {get}
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyUserDirectoryService?
	
}

public extension UserDirectoryService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyUserDirectoryService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unbox() else {return nil}
		
		if let alreadyInstantiated = cachedServices?.compactMap({ $0.unbox() as Self? }).first(where: { $0.config.serviceID == c.serviceID }) {
			return alreadyInstantiated.erase()
		}
		
		return self.init(config: c, globalConfig: gc).erase()
	}
	
}
