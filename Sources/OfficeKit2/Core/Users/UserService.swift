/*
 * UserService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/12.
 */

import Foundation

import GenericJSON
import ServiceKit



public typealias HashableUserService = DeportedHashability<any UserService>

public protocol UserService<UserType> : OfficeService {
	
	associatedtype UserType : User
	
	/** These are the properties the user service supports. */
	static var supportedUserProperties: Set<UserProperty> {get}
	
	/** Convert the user to a user printable string. Mostly used for logging. */
	func shortDescription(fromUser user: UserType) -> String
	
	/** The empty ID is reserved for the representation of the invalid user ID. */
	func string(fromUserID userID: UserType.IDType) -> String
	func userID(fromString string: String) throws -> UserType.IDType
	
	func string(fromPersistentUserID pID: UserType.PersistentIDType) -> String
	func persistentUserID(fromString string: String) throws -> UserType.PersistentIDType
	
	/**
	 Converts the given user to a JSON (generic codable storage representation).
	 
	 The representation is usually used to be stored as an underlying user in a ``UserWrapper``.
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
	 Implementations can, but are not required to validate the user wrapper for consistency with its underlying user. */
	func logicalUser(fromWrappedUser userWrapper: UserWrapper) throws -> UserType
	
	/** Returns the properties that were successfully applied to the user. */
	@discardableResult
	func applyHints(_ hints: [UserProperty: String?], toUser user: inout UserType, allowUserIDChange: Bool) -> Set<UserProperty>
	
	/**
	 Fetch and return the _only_ user matching the given ID.
	 
	 If _more than one_ user matches the given ID, the function should **throw an error**.
	 If _no_ users match the given ID, the method should return `nil`. */
	func existingUser(fromPersistentID pID: UserType.PersistentIDType, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> UserType?
	/**
	 Fetch and return the _only_ user matching the given ID.
	 
	 If _more than one_ user matches the given ID, the function should **throw an error**.
	 If _no_ users match the given ID, the method should return `nil`. */
	func existingUser(fromUserID uID: UserType.IDType, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> UserType?
	
	func listAllUsers(using services: Services) async throws -> [UserType]
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: UserType, using services: Services) async throws -> UserType
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: UserType, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> UserType
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: UserType, using services: Services) async throws
	
	var supportsPasswordChange: Bool {get}
	func changePassword(of user: UserType, to newPassword: String, using services: Services) throws
	
}


public extension Dictionary where Key == DeportedHashability<any UserService> {
	
	subscript(_ service: any UserService) -> Value? {
		get {self[.init(value: service, valueID: service.id)]}
		set {self[.init(value: service, valueID: service.id)] = newValue}
	}
	
}
