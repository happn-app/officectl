/*
 * SynologyService.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation

import CollectionConcurrencyKit
import Crypto
import Email
import GenericJSON
import Logging
import OfficeModelCore

import OfficeKit



public final class SynologyService : UserService {
	
	public static let providerID: String = "happn/synology"
	
	public typealias UserType = SynologyUser
	
	public let id: Tag
	public let name: String
	public let config: SynologyServiceConfig
	
	public let connector: SynologyConnector
	
	public convenience init(id: Tag, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try SynologyServiceConfig(json: jsonConfig)
		try self.init(id: id, name: name, synologyServiceConfig: config, workdir: workdir)
	}
	
	public init(id: Tag, name: String, synologyServiceConfig: SynologyServiceConfig, workdir: URL?) throws {
		self.id = id
		self.name = name
		self.config = synologyServiceConfig
		
		self.connector = try SynologyConnector(
			dsmURL: config.connectorSettings.dsmURL,
			username: config.connectorSettings.username,
			password: config.connectorSettings.password
		)
	}
	
	public func shortDescription(fromUser user: SynologyUser) -> String {
		return user.userPrincipalName.rawValue
	}
	
	public func string(fromUserID userID: Email) -> String {
		return userID.rawValue
	}
	
	public func userID(fromString string: String) throws -> Email {
		throw Err.__notImplemented
//		guard let e = Email(rawValue: string) else {
//			throw Err.invalidEmail(string)
//		}
//		return e
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
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?) async throws -> SynologyUser? {
		/* For a client credential flow, only “/.default” scopes are allowed. */
//		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		return try await SynologyUser.get(id: pID, propertiesToFetch: SynologyUser.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public func existingUser(fromID uID: Email, propertiesToFetch: Set<UserProperty>?) async throws -> SynologyUser? {
		/* For a client credential flow, only “/.default” scopes are allowed. */
//		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		/* M$’s API supports getting a user through his principal name directly (`GET /users/email@domain.com`).
		 * If it did not we’d have had to search or filter and check we only have one result.
		 * Search version: `GET /users?$search="userPrincipalName:email@domain.com"`
		 *    -> Not urlencoded for readability here, but must be of course;
		 *    -> The double-quotes MUST be there;
		 *    -> Additionally, the `ConsistencyLevel: eventual` header has to be set.
		 * Filter version: `GET /users?$filter=userPrincipalName eq 'email@domain.com'`
		 *    -> Not urlencoded for readability here, but must be of course;
		 *    -> The quotes MUST be there and MUST be single-quotes. */
		return try await SynologyUser.get(id: uID.rawValue, propertiesToFetch: SynologyUser.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?) async throws -> [SynologyUser] {
		/* For a client credential flow, only “/.default” scopes are allowed. */
//		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		return try await SynologyUser.getAll(includeSuspended: includeSuspended, propertiesToFetch: SynologyUser.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: SynologyUser) async throws -> SynologyUser {
		/* For a client credential flow, only “/.default” scopes are allowed. */
//		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		
		var user = user
		if user.mailNickname == nil {
			Conf.logger?.info("Asked to create a user but the mail nickname is not set. Using the local part of the user principal name.")
			user.mailNickname = user.userPrincipalName.localPart
		}
		if user.accountEnabled == nil {
			Conf.logger?.warning("Asked to create a user but account enabled is not set. Assuming true.")
			user.accountEnabled = true
		}
		if user.displayName == nil {
			Conf.logger?.warning("Asked to create a user without a display name, which is not supported by M$’s APIs. We infer a display name from the given name and the surname.")
			user.displayName = user.computedFullName
		}
		if user.passwordProfile == nil {
			/* Creating a user without a password is not possible.
			 * Let’s generate a password!
			 * A long and complex one. */
			OfficeKitConfig.logger?.warning("Auto-generating a random password for M$ user creation: creating a M$ user w/o a password is not supported.")
			user.passwordProfile = .init(
				forceChangePasswordNextSignIn: false,
				forceChangePasswordNextSignInWithMfa: false,
				password: .generatePassword(allowedChars: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=?!@#$%^&*")
			)
		}
		
		return try await user.create(connector: connector)
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: SynologyUser, propertiesToUpdate: Set<UserProperty>) async throws -> SynologyUser {
		/* For a client credential flow, only “/.default” scopes are allowed. */
//		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		return try await user.update(properties: SynologyUser.keysFromProperties(propertiesToUpdate), connector: connector)
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: SynologyUser) async throws {
		/* For a client credential flow, only “/.default” scopes are allowed. */
//		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		return try await user.delete(connector: connector)
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: SynologyUser, to newPassword: String) async throws {
		var user = user
		let passwordProperty = UserProperty(rawValue: SynologyService.providerID + "/password")
		guard user.oU_setValue(newPassword, forProperty: passwordProperty, convertMismatchingTypes: false).isSuccessful else {
			throw Err.internalError
		}
		_ = try await updateUser(user, propertiesToUpdate: [passwordProperty])
	}
	
}
