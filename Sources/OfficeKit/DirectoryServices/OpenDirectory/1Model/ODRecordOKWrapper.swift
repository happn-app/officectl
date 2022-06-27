/*
 * ODRecordOKWrapper.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/05.
 */

#if !canImport(DirectoryService) || !canImport(OpenDirectory)

public typealias ODRecordOKWrapper = LDAPInetOrgPersonWithObject

#else

import Foundation
import OpenDirectory

import Email

import OfficeModel



public struct ODRecordOKWrapper : DirectoryUser {
	
	public typealias IDType = LDAPDistinguishedName
	public typealias PersistentIDType = UUID
	
	public init(record r: ODRecord) throws {
		/* Is this making IO?
		 * Who knows…
		 * But it shouldn’t be; doc says if attributes is nil the method returns what’s in the cache. */
		let attributes = try r.recordDetails(forAttributes: nil)
		try self.init(recordAttributes: attributes)
		record = r
	}
	
	public init(recordAttributes attributes: [AnyHashable: Any]) throws {
		guard let idStr = (attributes[kODAttributeTypeMetaRecordName] as? [String])?.onlyElement else {
			throw InvalidArgumentError(message: "Cannot create an ODRecordOKWrapper if I don’t have an ID or have too many IDs in the record. Record attributes: \(attributes)")
		}
		userID = try LDAPDistinguishedName(string: idStr)
		
		let emails = (attributes[kODAttributeTypeEMailAddress] as? [String])?.compactMap{ Email(rawValue: $0) }
		
		persistentID = (attributes[kODAttributeTypeGUID] as? [String])?.onlyElement.flatMap{ UUID(uuidString: $0) }
		identifyingEmail = emails?.first
		otherEmails = emails.flatMap{ Array($0.dropFirst()) }
		firstName = (attributes[kODAttributeTypeFirstName] as? [String])?.onlyElement
		lastName = (attributes[kODAttributeTypeLastName] as? [String])?.onlyElement
	}
	
	public init(id theID: LDAPDistinguishedName, identifyingEmail ie: Email?, otherEmails oe: [Email], firstName fn: String? = nil, lastName ln: String? = nil) {
		userID = theID
		persistentID = nil
		
		identifyingEmail = ie
		otherEmails = oe
		firstName = fn
		lastName = ln
	}
	
	public var record: ODRecord?
	
	public var userID: LDAPDistinguishedName
	@RemoteProperty
	public var persistentID: UUID?
	public var remotePersistentID: RemoteProperty<UUID> {_persistentID}
	
	@RemoteProperty
	public var identifyingEmail: Email??
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {_identifyingEmail}
	@RemoteProperty
	public var otherEmails: [Email]?
	public var remoteOtherEmails: RemoteProperty<[Email]> {_otherEmails}
	
	@RemoteProperty
	public var firstName: String??
	public var remoteFirstName: RemoteProperty<String?> {_firstName}
	@RemoteProperty
	public var lastName: String??
	public var remoteLastName: RemoteProperty<String?> {_lastName}
	
	public let remoteNickname = RemoteProperty<String?>.unsupported
	
}

#endif
