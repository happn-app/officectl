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
			 * No idea why, but I tried everything I could think of.
			 * In particular a query on kODAttributeTypeRecordName does not work, it does like `record(withRecordType:, name:, attributes:)` does. */
			throw Err.invalidID
		}
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			do {
				/* Note:
				 * We use this convenience from OpenDirectory,
				 *  but we could use the exact same method as for the persistent ID search,
				 *  except the query would be inited with uid instead of guid. */
				let attributes = OpenDirectoryUser.attributeNamesFromProperties(propertiesToFetch)
				let record = try node.record(withRecordType: OpenDirectoryUser.recordType, name: uid, attributes: attributes.flatMap(Array.init))
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
		guard let uid = user.id.uid else {
			throw Err.invalidID
		}
		
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			/* Let’s first search all the user records (trust me on this, we’ll need them; see later). */
			let query = OpenDirectoryQuery(
				recordTypes: [OpenDirectoryUser.recordType],
				attribute: kODAttributeTypeMetaRecordName,
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
			let createdRecord = try node.createRecord(withRecordType: OpenDirectoryUser.recordType, name: uid, attributes: user.properties.mapValues{ $0.asMultiData })
			try createdRecord.recordDetails(forAttributes: [kODAttributeTypeMetaRecordName]) /* We fetch the record name because the creation operation does not return it. */
			let createdUser = try OpenDirectoryUser(record: createdRecord)
			guard createdUser.id == user.id else {
				/* We have created a user whose dn is not the same as the one we wanted.
				 * Let’s delete the created user and return an error. */
				let logMetadata: Logger.Metadata = [
					"created-dn": Logger.MetadataValue(stringLiteral: createdUser.id.stringValue),
					"expected-dn": Logger.MetadataValue(stringLiteral: user.id.stringValue)
				]
				Conf.logger?.info("Created user does not have the same DN as the expected one. Removing created user.", metadata: logMetadata)
				try createdRecord.delete()
				Conf.logger?.info("Done.", metadata: logMetadata)
				throw Err.createdDNDoesNotMatchExpectedDN(createdDN: createdUser.id, expectedDN: user.id)
			}
			return createdUser
		}
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: OpenDirectoryUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> OpenDirectoryUser {
		try await connector.connectIfNeeded()
		return try await connector.performOpenDirectoryCommunication{ @ODActor node in
			let record = try user.record(using: node)
			
			/* Let’s get the OD names of the attributes we want to update. */
			let attributeNames = Set(propertiesToUpdate.compactMap{ OpenDirectoryUser.propertyToAttributeNames[$0] }.flatMap{ $0 })
			
			/* Now let’s pre-compute the new attributes we will send.
			 * We do this in case some values are invalid, to fail the whole operation instead of having a partially updated record (some nodes auto-commit modifications). */
			var newAttributes = [String: Any?]()
			if attributeNames.contains(kODAttributeTypeMetaRecordName) || attributeNames.contains(kODAttributeTypeRecordName) {
				throw Err.unsupportedOperation
			}
			for attribute in attributeNames {
				/* AFAICT multi-data for setting a value always work, except maybe for record name and such, but setting those do not work whatever we do…
				 * I might be wrong, I did not test everything. */
				newAttributes[attribute] = user.properties[attribute]?.asMultiData
			}
			
			/* Now let’s set the attributes on the record. */
			for (attribute, value) in newAttributes {
				if let value {
					Conf.logger?.debug("Setting attribute \(attribute) to \(value)")
					try record.setValue(value, forAttribute: attribute)
				} else {
					Conf.logger?.debug("Removing attribute \(attribute)")
					try record.removeValues(forAttribute: attribute)
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
		throw Err.__notImplemented
	}
	
}
