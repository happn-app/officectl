/*
 * OpenDirectoryService.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/03.
 */

import Foundation
import OpenDirectory

import Email
import GenericJSON
import Logging
import UnwrapOrThrow

import OfficeKit
import ServiceKit



public final class OpenDirectoryService : UserService {
	
	public static let providerID: String = "happn/open-directory"
	
	public typealias UserType = OpenDirectoryUser
	
	public let id: String
	public let name: String
	public let config: OpenDirectoryServiceConfig
	
	public let connector: OpenDirectoryConnector
	
	public convenience init(id: String, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try OpenDirectoryServiceConfig(json: jsonConfig)
		self.init(id: id, name: name, openDirectoryServiceConfig: config)
	}
	
	public init(id: String, name: String, openDirectoryServiceConfig: OpenDirectoryServiceConfig) {
		self.id = id
		self.name = name
		self.config = openDirectoryServiceConfig
		
		self.connector = OpenDirectoryConnector(
			proxySettings: config.connectorSettings.proxySettings,
			nodeType: config.connectorSettings.nodeType,
			nodeCredentials: config.connectorSettings.nodeCredentials
		)
	}
	
	public func shortDescription(fromUser user: OpenDirectoryUser) -> String {
		return "OpenDirectoryUser<\(user.id)>"
	}
	
	public func string(fromUserID userID: String) -> String {
		return userID
	}
	
	public func userID(fromString string: String) throws -> String {
		return string
	}
	
	public func string(fromPersistentUserID pID: UUID) -> String {
		return pID.uuidString
	}
	
	public func persistentUserID(fromString string: String) throws -> UUID {
		return try UUID(uuidString: string) ?! Err.invalidPersistentID
	}
	
	public func alternateIDs(fromUserID userID: String) -> (regular: String, other: Set<String>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType>(fromUser user: OtherUserType) throws -> String where OtherUserType : User {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromID uID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> OpenDirectoryUser? {
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			do {
				/* Note:
				 * We use this convenience from OpenDirectory,
				 *  but we could use the exact same method as for the persistent ID search,
				 *  except the query would be inited with uid instead of guid. */
				let attributes = OpenDirectoryUser.attributeNamesFromProperties(propertiesToFetch)
				let record = try node.record(withRecordType: OpenDirectoryUser.recordType, name: uID, attributes: attributes.flatMap(Array.init))
				let user = try OpenDirectoryUser(record: record)
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
			let attributes = OpenDirectoryUser.attributeNamesFromProperties(propertiesToFetch)
			let users = try OpenDirectoryQuery(guid: pID, returnAttributes: attributes).execute(on: node).map{ try OpenDirectoryUser.init(record: $0) }
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
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			let attributes = OpenDirectoryUser.attributeNamesFromProperties(propertiesToFetch)
			return try OpenDirectoryQuery.forAllUsers(returnAttributes: attributes).execute(on: node).map{ try OpenDirectoryUser.init(record: $0) }
		}
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: OpenDirectoryUser, using services: Services) async throws -> OpenDirectoryUser {
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			/* Let’s first search all the user records (trust me on this, we’ll need them; see later). */
			let query = OpenDirectoryQuery(
				recordTypes: [OpenDirectoryUser.recordType],
				attribute: kODAttributeTypeRecordName,
				matchType: ODMatchType(kODMatchAny),
				queryValues: nil,
				returnAttributes: [kODAttributeTypeUniqueID],
				maximumResults: nil
			)
			let records = try query.execute(on: node)
			/* Now find the max UID of these records.
			 * We start at 501; users with a UID <= 500 are invisble. */
			var maxUID = 501
			for record in records {
				/* The kODAttributeTypeUniqueID should already be fetched, so asking for nil here is ok. */
				let attributes = try record.recordDetails(forAttributes: nil)
				guard let uidstr = try? attributes[kODAttributeTypeUniqueID].flatMap(OpenDirectoryAttributeValue.init(any:))?.asString,
						let uid = Int(uidstr)
				else {
					Conf.logger?.warning("Found non-int (or missing or invalid) uid \(String(describing: attributes[kODAttributeTypeUniqueID])) in user OpenDirectory record \(record).")
					continue
				}
				maxUID = max(maxUID, uid)
			}
			
			var user = user
			/* We set a new unique ID from the max we found earlier. */
			user.properties[kODAttributeTypeUniqueID] = .string(String(maxUID + 1))
			if user.properties[kODAttributeTypeFullName] == nil {user.properties[kODAttributeTypeFullName] = .string(user.computedFullName)}
			let createdRecord = try node.createRecord(withRecordType: OpenDirectoryUser.recordType, name: user.id, attributes: user.properties.mapValues{ $0.asMultiData })
			return try OpenDirectoryUser(record: createdRecord)
		}
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: OpenDirectoryUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> OpenDirectoryUser {
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			let record = try user.record(using: node)
			
			/* Let’s get the OD names of the attributes we want to update. */
			var attributeNames = Set(propertiesToUpdate.compactMap{ OpenDirectoryUser.propertyToAttributeNames[$0] }.flatMap{ $0 })
			
			/* Now let’s set the attributes on the record.
			 *
			 * From different tests I did, at least on our OpenDirectory setup (Server App), I gathered that:
			 * - Updating kODAttributeTypeRecordName does not work (fails with error “Connection failed to the directory server.”);
			 * - Updating kODAttributeTypeMetaRecordName does not work either (fails with error “An invalid attribute type was provided.”);
			 * - All other updates I tested (no much though) did work, even setting a value to multi-data when a string is “expected” (with valid UTF-8 data of course).
			 *
			 * From this, we do the update of kODAttributeTypeRecordName and kODAttributeTypeMetaRecordName if applicable first, to fail as early as possible. */
			if attributeNames.remove(kODAttributeTypeRecordName) != nil {
				Conf.logger?.debug("Setting attribute \(kODAttributeTypeRecordName) to \(user.id)")
				try record.setValue(user.id, forAttribute: kODAttributeTypeRecordName)
			}
			let sortedAttributesName = (
				[attributeNames.remove(kODAttributeTypeMetaRecordName)].compactMap{ $0 } +
				Array(attributeNames)
			)
			for attributeName in sortedAttributesName {
				if let value = user.properties[attributeName]?.asMultiData {
					Conf.logger?.debug("Setting attribute \(attributeName) to \(value)")
					try record.setValue(value, forAttribute: attributeName)
				} else {
					Conf.logger?.debug("Removing attribute \(attributeName)")
					try record.removeValues(forAttribute: attributeName)
				}
			}
			
			/* Finally, synchronize the node because some do not automatically. */
			try record.synchronize()
			/* It seems some attributes (I don’t know which exactly, but “mails” is) are dropped from the record after synchronization; let’s re-fetch them.
			 * We do not fail if the fetch does not work because the update has been done anyway.
			 *
			 * I know recordDetails(forAttributes:) is supposed to be able to take an _array_ of attributes and I should not have to iterate over attributeNames,
			 *  but it seems if I do not do that, it does not work reliably.
			 * OpenDirectory is amazing. */
			attributeNames.forEach{ attributeName in
				_ = try? record.recordDetails(forAttributes: [attributeName])
			}
			
			return try OpenDirectoryUser(record: record)
		}
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: OpenDirectoryUser, using services: Services) async throws {
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			let record = try user.record(using: node)
			try record.delete()
		}
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: OpenDirectoryUser, to newPassword: String, using services: Services) async throws {
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			let record = try user.record(using: node)
			try record.changePassword(nil, toPassword: newPassword)
		}
	}
	
}
