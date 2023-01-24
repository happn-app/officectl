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
import OfficeModelCore
import Logging
import UnwrapOrThrow

import OfficeKit



public final class LDAPService : UserService, AuthenticatorService {
	
	public static let providerID: String = "happn/ldap"
	
	public typealias UserType = LDAPObject
	
	public let id: Tag
	public let name: String
	public let config: LDAPServiceConfig
	
	public let connector: LDAPConnector
	
	public convenience init(id: Tag, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try LDAPServiceConfig(json: jsonConfig)
		self.init(id: id, name: name, ldapServiceConfig: config)
	}
	
	public init(id: Tag, name: String, ldapServiceConfig: LDAPServiceConfig) {
		self.id = id
		self.name = name
		self.config = ldapServiceConfig
		
		self.connector = LDAPConnector(
			ldapURL: ldapServiceConfig.connectorSettings.ldapURL,
			version: ldapServiceConfig.connectorSettings.ldapVersion,
			startTLS: ldapServiceConfig.connectorSettings.startTLS,
			auth: ldapServiceConfig.connectorSettings.auth
		)
	}
	
	public func shortDescription(fromUser user: LDAPObject) -> String {
		return user.id.uid ?? "nouid:\(user.id.stringValue)"
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
	
	public func alternateIDs(fromUserID userID: LDAPDistinguishedName) -> (regular: LDAPDistinguishedName, other: Set<LDAPDistinguishedName>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> LDAPDistinguishedName {
		if let user = user as? UserType {
			return user.oU_id
		}
		
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ try? LDAPDistinguishedName(string: $0) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromID uID: LDAPDistinguishedName, propertiesToFetch: Set<UserProperty>?) async throws -> LDAPObject? {
		try await connector.connectIfNeeded()
		
		let request = LDAPSearchRequest(base: uID, scope: .base, attributesToFetch: LDAPObject.attributeNamesFromProperties(propertiesToFetch))
		let objects = try await LDAPObject.search(request, connector: connector).results.filter(\.isInetOrgPerson)
		
		guard let object = objects.first else {
			return nil
		}
		guard objects.count == 1 else {
			throw OfficeKitError.tooManyUsersFromAPI(users: objects)
		}
		return object
	}
	
	public func existingUser(fromPersistentID pID: Never, propertiesToFetch: Set<UserProperty>?) async throws -> LDAPObject? {
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?) async throws -> [LDAPObject] {
		try await connector.connectIfNeeded()
		
		let request = LDAPSearchRequest(base: config.peopleDN + config.baseDN, scope: .children, attributesToFetch: LDAPObject.attributeNamesFromProperties(propertiesToFetch))
		return try await LDAPObject.search(request, connector: connector).results.filter(\.isInetOrgPerson)
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: LDAPObject) async throws -> LDAPObject {
		guard user.isInetOrgPerson else {
			throw Err.invalidLDAPObjectClass
		}
		
		try await connector.connectIfNeeded()
		
		let res = try await user.create(connector: connector)
		guard res.isInetOrgPerson else {
			throw Err.invalidLDAPObjectClass
		}
		return res
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: LDAPObject, propertiesToUpdate: Set<UserProperty>) async throws -> LDAPObject {
		guard user.isInetOrgPerson else {
			throw Err.invalidLDAPObjectClass
		}
		
		try await connector.connectIfNeeded()
		return try await user.update(properties: Set(LDAPObject.oidsFromProperties(propertiesToUpdate)), connector: connector)
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: LDAPObject) async throws {
		guard user.isInetOrgPerson else {
			throw Err.invalidLDAPObjectClass
		}
		
		try await connector.connectIfNeeded()
		try await user.delete(connector: connector)
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: LDAPObject, to newPassword: String) async throws {
		guard user.isInetOrgPerson else {
			throw Err.invalidLDAPObjectClass
		}
		
		try await connector.connectIfNeeded()
		try await user.updatePassword(newPassword, connector: connector)
	}
	
	/* ***************************
	   MARK: Authenticator Service
	   *************************** */
	
	public typealias AuthenticatedUserType = LDAPObject
	public typealias AuthenticationChallenge = (username: LDAPDistinguishedName, password: String)
	
	public func authenticate(with challenge: (username: LDAPDistinguishedName, password: String)) async throws -> LDAPDistinguishedName {
		do {
			guard !challenge.password.isEmpty else {
				throw Err.passwordIsEmpty
			}
			
			let connector = LDAPConnector(
				ldapURL: config.connectorSettings.ldapURL,
				version: config.connectorSettings.ldapVersion,
				startTLS: config.connectorSettings.startTLS,
				auth: .userPass(username: challenge.username.stringValue, password: challenge.password)
			)
			try await connector.connect()
			_ = try? await connector.disconnect()
			return challenge.username
			
		} catch let error as OpenLDAPError where error.isInvalidPassError {
			throw OfficeKitError.invalidUsernameOrPassword
		}
	}
	
}
