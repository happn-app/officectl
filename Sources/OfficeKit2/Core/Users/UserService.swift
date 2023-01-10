/*
 * UserService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/12.
 */

import Foundation

import GenericJSON
import ServiceKit



public protocol UserService<UserType> : OfficeService {
	
	associatedtype UserType : User
	
	/** Convert the user to a user printable string. Mostly used for logging. */
	func shortDescription(fromUser user: UserType) -> String
	
	func string(fromUserID userID: UserType.UserIDType) -> String
	func userID(fromString string: String) throws -> UserType.UserIDType
	
	func string(fromPersistentUserID pID: UserType.PersistentUserIDType) -> String
	func persistentUserID(fromString string: String) throws -> UserType.PersistentUserIDType
	
	/**
	 Converts the given user to a JSON (generic codable storage representation).
	 
	 The representation is usually stored as an underlying user in a ``UserWrapper``.
	 It should contain as much as possible from the original user. */
	func json(fromUser user: UserType) throws -> JSON
	
	/**
	 Returns the different possible IDs from a given ID.
	 
	 Example: If you expect all of your users to be on a given domain, but you have a domain alias, and the underlying service do not support domain alias.
	 In this case, you’d return `(regular: "user@main.domain", other: ["user@alias.domain"])`.
	 
	 In most cases, there should not be alternate IDs.
	 In particular, if your service supports domain aliases natively, do **not** return any alternate IDs:
	  the IDs of your user will predictably always be the one of the main domain.
	 
	 If you have alternate IDs, when getting the existing user for a given ID, alternate IDs should also be searched. */
	func alternateIDs(fromUserID userID: UserType.UserIDType) -> (regular: UserType.UserIDType, other: Set<UserType.UserIDType>)
	
	/**
	 Returns the user ID the user should _logically_ get from the given user from another service.
	 
	 In theory, if you’re passed a user from the same service, the ID should be the same.
	 In practice, sometimes the IDs can be incorrect.
	 
	 For instance if you create the email address of a user using the format `firstname.lastname@company.domain` and replacing spaces by dashes,
	  it can happen that following a user error the spaces are removed instead of being replaced by dashes.
	 
	 To avoid this kind of issues and make the user uniquing go well between services,
	  you _should_ always try and recognize the ID of the given user and work from that instead of working directly from other properties.
	 For instance if your IDs are DNs and you get a user whose ID is an email, work directly from the email. */
	func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> UserType.UserIDType
	
	/**
	 Fetch and return the _only_ user matching the given ID.
	 If `propertiesToFetch` is `nil`, **all** the properties supported should be fetched.
	 
	 If _more than one_ user matches the given ID, the function should **throw an error**.
	 If _no_ users match the given ID, the method should return `nil`. */
	func existingUser(fromPersistentID pID: UserType.PersistentUserIDType, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> UserType?
	/**
	 Fetch and return the _only_ user matching the given ID.
	 If `propertiesToFetch` is `nil`, **all** the properties supported should be fetched.
	 
	 If _more than one_ user matches the given ID, the function should **throw an error**.
	 If _no_ users match the given ID, the method should return `nil`.
	 
	 If you support alternate IDs, you **must** also search for alternate IDs of the given ID.
	 In general all aliases of the ID should be searched (if the underlying service supports domain aliases for instance, searching for an ID on one of the alias must find the user). */
	func existingUser(fromID uID: UserType.UserIDType, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> UserType?
	
	/**
	 List all of the users in the service.
	 If `propertiesToFetch` is `nil`, **all** the properties supported should be fetched. */
	func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [UserType]
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: UserType, using services: Services) async throws -> UserType
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: UserType, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> UserType
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: UserType, using services: Services) async throws
	
	var supportsPasswordChange: Bool {get}
	func changePassword(of user: UserType, to newPassword: String, using services: Services) async throws
	
}


public typealias HashableUserService = DeportedHashability<any UserService>
public extension DeportedHashability where ValueType == any UserService {
	
	init(_ val: ValueType) {
		self.init(value: val, valueID: val.id)
	}
	
}

public extension Dictionary where Key == HashableUserService {
	
	subscript(_ service: any UserService) -> Value? {
		get {self[.init(value: service, valueID: service.id)]}
		set {self[.init(value: service, valueID: service.id)] = newValue}
	}
	
}
