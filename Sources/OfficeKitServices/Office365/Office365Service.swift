/*
 * Office365Service.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/03/03.
 */

import Foundation

import CollectionConcurrencyKit
import Crypto
import Email
import GenericJSON
import Logging
import OfficeModelCore

import OfficeKit



public final class Office365Service : UserService {
	
	public static let providerID: String = "happn/office365"
	
	public typealias UserType = Office365User
	
	public let id: Tag
	public let name: String
	public let config: Office365ServiceConfig
	
	public let connector: Office365Connector
	
	public convenience init(id: Tag, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try Office365ServiceConfig(json: jsonConfig)
		try self.init(id: id, name: name, office365ServiceConfig: config, workdir: workdir)
	}
	
	public init(id: Tag, name: String, office365ServiceConfig: Office365ServiceConfig, workdir: URL?) throws {
		self.id = id
		self.name = name
		self.config = office365ServiceConfig
		
		self.connector = try Office365Connector(
			tenantID: config.connectorSettings.tenantID,
			clientID: config.connectorSettings.clientID,
			grant: config.connectorSettings.grant,
			workdir: workdir
		)
	}
	
	public func shortDescription(fromUser user: Office365User) -> String {
		return user.userPrincipalName.rawValue
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
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?) async throws -> Office365User? {
		/* For a client credential flow, only “/.default” scopes are allowed. */
		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		return try await Office365User.get(id: pID, propertiesToFetch: Office365User.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public func existingUser(fromID uID: Email, propertiesToFetch: Set<UserProperty>?) async throws -> Office365User? {
		/* For a client credential flow, only “/.default” scopes are allowed. */
		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		/* M$’s API supports getting a user through his principal name directly (`GET /users/email@domain.com`).
		 * If it did not we’d have had to search or filter and check we only have one result.
		 * Search version: `GET /users?$search="userPrincipalName:email@domain.com"`
		 *    -> Not urlencoded for readability here, but must be of course;
		 *    -> The double-quotes MUST be there;
		 *    -> Additionally, the `ConsistencyLevel: eventual` header has to be set.
		 * Filter version: `GET /users?$filter=userPrincipalName eq 'email@domain.com'`
		 *    -> Not urlencoded for readability here, but must be of course;
		 *    -> The quotes MUST be there and MUST be single-quotes. */
		return try await Office365User.get(id: uID.rawValue, propertiesToFetch: Office365User.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?) async throws -> [Office365User] {
		/* For a client credential flow, only “/.default” scopes are allowed. */
		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		return try await Office365User.getAll(includeSuspended: includeSuspended, propertiesToFetch: Office365User.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: Office365User) async throws -> Office365User {
		/* For a client credential flow, only “/.default” scopes are allowed. */
		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		throw Err.__notImplemented
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: Office365User, propertiesToUpdate: Set<UserProperty>) async throws -> Office365User {
		/* For a client credential flow, only “/.default” scopes are allowed. */
		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		throw Err.__notImplemented
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: Office365User) async throws {
		/* For a client credential flow, only “/.default” scopes are allowed. */
		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		throw Err.__notImplemented
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: Office365User, to newPassword: String) async throws {
		/* For a client credential flow, only “/.default” scopes are allowed. */
		try await connector.increaseScopeIfNeeded("https://graph.microsoft.com/.default")
		throw Err.__notImplemented
	}
	
}
