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
	
	/** Empty ids are **not supported**. There are no other restrictions. */
	func string(from userId: UserType.UserIdType) -> String
	func userId(from string: String) throws -> UserType.UserIdType
	
	/** Converts the given user to a JSON representation.
	
	The JSON returned by this function doesn’t have to be an exact representation
	of the given user. In particular it isn’t expected to be necessarily possible
	to re-create the user back from the JSON.
	
	The JSON representation is intended to be sent to an external directory
	service, when creating a logical user from a user from another service. */
	func exportableJSON(from user: UserType) throws -> JSON
	
	/** If possible, convert the given email to a user with as much information
	as possible in your directory.
	
	The conversion should not fetch anything from the directory. It is simply a
	representation of how the given email _should_ be created in the directory if
	it were to be created in it. */
	func logicalUser(fromEmail email: Email) throws -> UserType?
	/** If possible, convert the given user in the given directory to a user with
	as much information as possible in your directory.
	
	The conversion should not fetch anything from neither the source nor the
	destination directory. It is simply a representation of how the given user
	_should_ be created in the directory if it were to be created in it. */
	func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType) throws -> UserType?
	
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
	/** Fetch and return the _only_ user matching the given email.
	
	If _more than one_ user matches the given email, the function should return a
	**failed** future. If _no_ users match the given email, the method should
	return a succeeded future with a `nil` user. */
	func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?>
	/** Fetch and return the _only_ user matching the given user in the given
	directory.
	
	If _more than one_ user matches the given user, the function should return a
	**failed** future. If _no_ users match the given user, the method should
	return a succeeded future with a `nil` user. */
	func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<UserType?>
	
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
