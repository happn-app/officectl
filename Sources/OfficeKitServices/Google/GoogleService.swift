/*
 * GoogleService.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/24.
 */

import Foundation

import CollectionConcurrencyKit
import Crypto
import Email
import GenericJSON
import Logging
import ServiceKit

import OfficeKit2



public final class GoogleService : UserService {
	
	public static let providerID: String = "happn/google"
	
	public typealias UserType = GoogleUser
	
	public let id: String
	public let config: GoogleServiceConfig
	
	public let connector: GoogleConnector
	
	public convenience init(id: String, jsonConfig: JSON) throws {
		let config = try GoogleServiceConfig(json: jsonConfig)
		try self.init(id: id, googleServiceConfig: config)
	}
	
	public init(id: String, googleServiceConfig: GoogleServiceConfig) throws {
		self.id = id
		self.config = googleServiceConfig
		
		self.connector = try GoogleConnector(
			jsonCredentialsURL: URL(fileURLWithPath: config.connectorSettings.superuserJSONCredsPath),
			userBehalf: config.connectorSettings.adminEmail?.rawValue
		)
	}
	
	public var supportedUserProperties: Set<UserProperty> {
		return Set(GoogleUser.propertyToKeys.filter{ !$0.value.isEmpty }.map{ $0.key })
	}
	
	public func shortDescription(fromUser user: GoogleUser) -> String {
		return "GoogleUser<\(user.primaryEmail.rawValue)>"
	}
	
	public func string(fromUserID userID: Email) -> String {
		return userID.rawValue
	}
	
	public func userID(fromString string: String) throws -> Email {
		guard let e = Email(rawValue: string) else {
			throw Err.invalidEmail(string)
		}
		return e
	}
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: GoogleUser) throws -> JSON {
		return try JSON(encodable: user)
	}
	
	public func alternateIDs(fromUserID userID: Email) -> (regular: Email, other: Set<Email>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> Email {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ Email(rawValue: $0) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> GoogleUser? {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		return try await GoogleUser.get(id: pID, propertiesToFetch: GoogleUser.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public func existingUser(fromID uID: Email, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> GoogleUser? {
		/* Gougle returns the user whether from persistent or standard id. */
		return try await existingUser(fromPersistentID: uID.rawValue, propertiesToFetch: propertiesToFetch, using: services)
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [GoogleUser] {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user.readonly")
		let users = try await config.primaryDomains.asyncFlatMap{
			try await GoogleUser.search(
				SearchRequest(domain: $0, query: !includeSuspended ? "isSuspended=false" : nil),
				propertiesToFetch: GoogleUser.keysFromProperties(propertiesToFetch),
				connector: connector
			)
		}
		return users
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: GoogleUser, using services: Services) async throws -> GoogleUser {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		return try await user.create(connector: connector)
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: GoogleUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> GoogleUser {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		return try await user.update(properties: GoogleUser.keysFromProperties(propertiesToUpdate), connector: connector)
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: GoogleUser, using services: Services) async throws {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		return try await user.delete(connector: connector)
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: GoogleUser, to newPassword: String, using services: Services) async throws {
		var user = user
		let passwordProperty = UserProperty(rawValue: "google/password")
		guard user.oU_setValue(newPassword, forProperty: passwordProperty, allowIDChange: false, convertMismatchingTypes: false) else {
			throw Err.internalError
		}
		_ = try await updateUser(user, propertiesToUpdate: [passwordProperty], using: services)
	}
	
}
