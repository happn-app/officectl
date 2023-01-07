/*
 * LDAPService.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import COpenLDAP
import Email
import GenericJSON
import Logging
import UnwrapOrThrow

import OfficeKit2
import ServiceKit



public final class LDAPService : UserService {
	
	public static let providerID: String = "happn/ldap"
	
	public typealias UserType = LDAPObject
	
	public let id: String
	public let config: LDAPServiceConfig
	
	public let connector: LDAPConnector
	
	public convenience init(id: String, jsonConfig: JSON) throws {
		let config = try LDAPServiceConfig(json: jsonConfig)
		self.init(id: id, ldapServiceConfig: config)
	}
	
	public init(id: String, ldapServiceConfig: LDAPServiceConfig) {
		self.id = id
		self.config = ldapServiceConfig
		
		self.connector = LDAPConnector(
			ldapURL: ldapServiceConfig.connectorSettings.ldapURL,
			version: ldapServiceConfig.connectorSettings.ldapVersion,
			startTLS: ldapServiceConfig.connectorSettings.startTLS,
			auth: ldapServiceConfig.connectorSettings.auth
		)
	}
	
	public var supportedUserProperties: Set<UserProperty> {
		/* LDAP supports a lot of properties, but we map only a very few of them, at least for now.
		 * Later, we should get the list of supported properties of the server (presumably at init time)
		 *  to get the list of actually supported properties by the service. */
		return UserProperty.standardProperties
	}
	
	public func shortDescription(fromUser user: LDAPObject) -> String {
		return user.id.stringValue
	}
	
	public func string(fromUserID userID: LDAPDistinguishedName) -> String {
		return userID.stringValue
	}
	
	public func userID(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func string(fromPersistentUserID pID: Never) -> String {
	}
	
	public func persistentUserID(fromString string: String) throws -> Never {
		throw Err.serviceDoesNotHavePersistentID
	}
	
	public func json(fromUser user: LDAPObject) throws -> JSON {
		return try JSON(encodable: user)
	}
	
	public func alternateIDs(fromUserID userID: LDAPDistinguishedName) -> (regular: LDAPDistinguishedName, other: Set<LDAPDistinguishedName>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> LDAPDistinguishedName {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ try? LDAPDistinguishedName(string: $0) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromID uID: LDAPDistinguishedName, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> LDAPObject? {
		try await connector.connectIfNeeded()
		return try await connector.performLDAPCommunication{ ldap in
			throw Err.__notImplemented
		}
	}
	
	public func existingUser(fromPersistentID pID: Never, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> LDAPObject? {
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [LDAPObject] {
		try await connector.connectIfNeeded()
		return try await connector.performLDAPCommunication{ ldap in
			throw Err.__notImplemented
		}
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: LDAPObject, using services: Services) async throws -> LDAPObject {
		try await connector.connectIfNeeded()
		return try await connector.performLDAPCommunication{ ldap in
			throw Err.__notImplemented
		}
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: LDAPObject, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> LDAPObject {
		try await connector.connectIfNeeded()
		return try await connector.performLDAPCommunication{ ldap in
			throw Err.__notImplemented
		}
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: LDAPObject, using services: Services) async throws {
		try await connector.connectIfNeeded()
		return try await connector.performLDAPCommunication{ ldap in
			throw Err.__notImplemented
		}
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: LDAPObject, to newPassword: String, using services: Services) async throws {
		try await connector.connectIfNeeded()
		return try await connector.performLDAPCommunication{ ldap in
			throw Err.__notImplemented
		}
	}
	
}
