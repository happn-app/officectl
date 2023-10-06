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
import OfficeModelCore

import OfficeKit



public final class GoogleService : UserService {
	
	public static let providerID: String = "happn/google"
	
	public typealias UserType = GoogleUser
	
	public let id: Tag
	public let name: String
	public let config: GoogleServiceConfig
	
	public let connector: GoogleConnector
	
	public convenience init(id: Tag, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try GoogleServiceConfig(json: jsonConfig)
		try self.init(id: id, name: name, googleServiceConfig: config, workdir: workdir)
	}
	
	public init(id: Tag, name: String, googleServiceConfig: GoogleServiceConfig, workdir: URL?) throws {
		self.id = id
		self.name = name
		self.config = googleServiceConfig
		
		self.connector = try GoogleConnector(
			jsonCredentialsURL: URL(fileURLWithPath: config.connectorSettings.superuserJSONCredsPath, isDirectory: false, relativeTo: workdir),
			userBehalf: config.connectorSettings.adminEmail?.rawValue
		)
	}
	
	public func shortDescription(fromUser user: GoogleUser) -> String {
		return user.primaryEmail.rawValue
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
	
	public func alternateIDs(fromUserID userID: Email) -> (regular: Email, other: Set<Email>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> Email {
		if let user = user as? UserType {
			return user.oU_id
		}
		
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ Email(rawValue: $0) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?) async throws -> GoogleUser? {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		return try await GoogleUser.get(id: pID, propertiesToFetch: GoogleUser.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public func existingUser(fromID uID: Email, propertiesToFetch: Set<UserProperty>?) async throws -> GoogleUser? {
		/* Gougle returns the user whether from persistent or standard id. */
		return try await existingUser(fromPersistentID: uID.rawValue, propertiesToFetch: propertiesToFetch)
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?) async throws -> [GoogleUser] {
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
	public func createUser(_ user: GoogleUser) async throws -> GoogleUser {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		var user = user
		if user.password == nil {
			/* Creating a user without a password is not possible.
			 * Let’s generate a password!
			 * A long and complex one. */
			OfficeKitConfig.logger?.warning("Auto-generating a random password for gougle user creation: creating a gougle user w/o a password is not supported.")
			let passwordProperty = UserProperty(rawValue: GoogleService.providerID + "/password")
			let newPassword = String.generatePassword(allowedChars: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=?!@#$%^&*")
			guard user.oU_setValue(newPassword, forProperty: passwordProperty, convertMismatchingTypes: false).isSuccessful else {
				throw Err.internalError
			}
		}
		return try await user.create(connector: connector)
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: GoogleUser, propertiesToUpdate: Set<UserProperty>) async throws -> GoogleUser {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		return try await user.update(properties: GoogleUser.keysFromProperties(propertiesToUpdate), connector: connector)
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: GoogleUser) async throws {
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		return try await user.delete(connector: connector)
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: GoogleUser, to newPassword: String) async throws {
		var user = user
		let passwordProperty = UserProperty(rawValue: GoogleService.providerID + "/password")
		guard user.oU_setValue(newPassword, forProperty: passwordProperty, convertMismatchingTypes: false).isSuccessful else {
			throw Err.internalError
		}
		_ = try await updateUser(user, propertiesToUpdate: [passwordProperty])
	}
	
}
