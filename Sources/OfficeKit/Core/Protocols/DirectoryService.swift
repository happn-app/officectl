/*
 * DirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 22/05/2019.
 */

import Foundation

import Async



public protocol DirectoryService {
	
	/** The id of the linked provider, e.g. "internal_openldap". Those are static
	in OfficeKit. */
	static var providerId: String {get}
	
	associatedtype ConfigType : OfficeKitServiceConfig
	associatedtype UserType : DirectoryUser
	
	var config: ConfigType {get}
	
	/** If possible, convert the given email to a user with as much information
	as possible in your directory.
	
	The conversion should not fetch anything from the directory. It is simply a
	representation of how the given email _should_ be created in the directory if
	it were to be created in it. */
	func logicalUser(from email: Email) throws -> UserType?
	/** If possible, convert the given user in the given directory to a user with
	as much information as possible in your directory.
	
	The conversion should not fetch anything from neither the source nor the
	destination directory. It is simply a representation of how the given user
	_should_ be created in the directory if it were to be created in it. */
	func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> UserType?
	
	/** Fetch and return the _only_ user matching the given email.
	
	If _more than one_ user matches the given email, the function should return a
	**failed** future. If _no_ users match the given email, the method should
	return a succeeded future with a `nil` user. */
	func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<UserType?>
	/** Fetch and return the _only_ user matching the given user in the given
	directory.
	
	If _more than one_ user matches the given user, the function should return a
	**failed** future. If _no_ users match the given user, the method should
	return a succeeded future with a `nil` user. */
	func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<UserType?>
	
	func listAllUsers() -> Future<[UserType]>
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: UserType) -> Future<UserType>
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: UserType, propertiesToUpdate: Set<DirectoryUserProperty>) -> Future<UserType>
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: UserType) -> Future<Void>
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: UserType) throws -> ResetPasswordAction
	
}
