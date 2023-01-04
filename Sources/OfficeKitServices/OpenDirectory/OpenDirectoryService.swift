/*
 * OpenDirectoryService.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/03.
 */

import Foundation

import Email
import GenericJSON
import UnwrapOrThrow

import OfficeKit2
import ServiceKit



public final class OpenDirectoryService : UserService {
	
	public static let providerID: String = "happn/open-directory"
	
	public typealias UserType = OpenDirectoryUser
	
	public let id: String
	public let config: OpenDirectoryServiceConfig
	
	public let connector: OpenDirectoryConnector
	
	public convenience init(id: String, jsonConfig: JSON) throws {
		let config = try OpenDirectoryServiceConfig(json: jsonConfig)
		self.init(id: id, openDirectoryServiceConfig: config)
	}
	
	public init(id: String, openDirectoryServiceConfig: OpenDirectoryServiceConfig) {
		self.id = id
		self.config = openDirectoryServiceConfig
		
		self.connector = OpenDirectoryConnector(
			proxySettings: config.connectorSettings.proxySettings,
			nodeType: config.connectorSettings.nodeType,
			nodeCredentials: config.connectorSettings.nodeCredentials
		)
	}
	
	public var supportedUserProperties: Set<UserProperty> {
		/* OpenDirectory supports a lot of properties, but we map only a very few of them, at least for now.
		 * Later, we should call `supportedAttributes(forRecordType: kODRecordTypeUsers)` on the node (presumably at init time)
		 *  to get the list of actually supported properties by the node.  */
		return UserProperty.standardProperties
	}
	
	public func shortDescription(fromUser user: OpenDirectoryUser) -> String {
		return user.id.stringValue
	}
	
	public func string(fromUserID userID: LDAPDistinguishedName) -> String {
		return userID.stringValue
	}
	
	public func userID(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func string(fromPersistentUserID pID: UUID) -> String {
		return pID.uuidString
	}
	
	public func persistentUserID(fromString string: String) throws -> UUID {
		return try UUID(uuidString: string) ?! Err.invalidPersistentID
	}
	
	public func json(fromUser user: OpenDirectoryUser) throws -> JSON {
		return try JSON(encodable: user)
	}
	
	public func alternateIDs(fromUserID userID: LDAPDistinguishedName) -> (regular: LDAPDistinguishedName, other: Set<LDAPDistinguishedName>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType>(fromUser user: OtherUserType) throws -> LDAPDistinguishedName where OtherUserType : User {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ try? LDAPDistinguishedName(string: $0) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromID uID: LDAPDistinguishedName, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> OpenDirectoryUser? {
		try await connector.connectIfNeeded()
		guard let uid = uID.uid else {
			/* Sadly the search in OpenDirectory cannot be done on a full DN apparently.
			 * No idea why, but I tried everything I could think of. */
			throw Err.invalidID
		}
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			do {
				let record = try node.record(withRecordType: OpenDirectoryUser.recordType, name: uid, attributes: nil)
				let user = try OpenDirectoryUser(record: record)
				print(user.id)
				guard user.id == uID else {
					/* We verify we did get the correct user (search was done on uid only, not full dn). */
					return nil
				}
				return user
			} catch let error as NSError {
				guard error.code != 0/* || error.domain != "Foundation._GenericObjCError"*/ else {
					/* So that’s a fun case.
					 * OpenDirectory has not been refined AT ALL for Swift.
					 * The original Objective-C method returns nil and sets *error when there is an error and returns nil if no record match.
					 * Except it seems Swift understands the nil return value to be a failure whatever value is set to *error, and thus we get here, with a `nil` error…
					 *
					 * I have not tested thoroughly these assertions, but they seems most likely.
					 *
					 * We assume no error will ever have a code of 0.
					 * We could also check for a domain equal to Foundation._GenericObjCError, but that seems too fragile. */
					return nil
				}
				throw error
			}
		}
	}
	
	public func existingUser(fromPersistentID pID: UUID, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> OpenDirectoryUser? {
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			/* The “as!” should be valid; OpenDirectory is simply not updated anymore and the returned array is not typed.
			 * But doc says this method returns an array of ODRecord. */
			let users = try OpenDirectoryQuery(guid: pID).execute(on: node).map{ try OpenDirectoryUser.init(record: $0) }
			guard !users.isEmpty else {
				return nil
			}
			guard let record = users.onlyElement else {
				throw OfficeKitError.tooManyUsersFromAPI(users: users)
			}
			return record
		}
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [OpenDirectoryUser] {
		throw Err.__notImplemented
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: OpenDirectoryUser, using services: Services) async throws -> OpenDirectoryUser {
		throw Err.__notImplemented
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: OpenDirectoryUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> OpenDirectoryUser {
		throw Err.__notImplemented
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: OpenDirectoryUser, using services: Services) async throws {
		throw Err.__notImplemented
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: OpenDirectoryUser, to newPassword: String, using services: Services) async throws {
		throw Err.__notImplemented
	}
	
}
