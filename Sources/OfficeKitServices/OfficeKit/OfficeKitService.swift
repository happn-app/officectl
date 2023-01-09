/*
 * OfficeKitService.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import Email
import GenericJSON
import ServiceKit

import OfficeKit2



public final class OfficeKitService : UserService {
	
	public static let providerID: String = "happn/officekit"
	
	public typealias UserType = OfficeKitUser
	
	public let id: String
	public let config: OfficeKitServiceConfig
	
	public convenience init(id: String, jsonConfig: JSON) throws {
		let config = try OfficeKitServiceConfig(json: jsonConfig)
		try self.init(id: id, officeKitServiceConfig: config)
	}
	
	public init(id: String, officeKitServiceConfig: OfficeKitServiceConfig) {
		self.id = id
		self.config = officeKitServiceConfig
	}
	
	public var supportedUserProperties: Set<UserProperty> {
		return config.supportedProperties
	}
	
	public func shortDescription(fromUser user: OfficeKitUser) -> String {
		return "OfficeKitUser<\(user.id)>"
	}
	
	public func string(fromUserID userID: String) -> String {
		return userID
	}
	
	public func userID(fromString string: String) throws -> String {
		return string
	}
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: OfficeKitUser) throws -> JSON {
		return try JSON(encodable: user)
	}
	
	public func alternateIDs(fromUserID userID: String) -> (regular: String, other: Set<String>) {
#warning("TODO: Use config.alternateUserIDsBuilders")
		return (userID, [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> String {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromID uID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> OfficeKitUser? {
		throw Err.__notImplemented
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> OfficeKitUser? {
		throw Err.__notImplemented
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [OfficeKitUser] {
		throw Err.__notImplemented
	}
	
	public var supportsUserCreation: Bool {
		return config.supportsUserCreation
	}
	public func createUser(_ user: OfficeKitUser, using services: Services) async throws -> OfficeKitUser {
		throw Err.__notImplemented
	}
	
	public var supportsUserUpdate: Bool {
		return config.supportsUserUpdate
	}
	public func updateUser(_ user: OfficeKitUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> OfficeKitUser {
		throw Err.__notImplemented
	}
	
	public var supportsUserDeletion: Bool {
		return config.supportsUserDeletion
	}
	public func deleteUser(_ user: OfficeKitUser, using services: Services) async throws {
		throw Err.__notImplemented
	}
	
	public var supportsPasswordChange: Bool {
		return config.supportsPasswordChange
	}
	public func changePassword(of user: OfficeKitUser, to newPassword: String, using services: Services) async throws {
		throw Err.__notImplemented
	}
	
}
