/*
 * ODRecordOKWrapper.swift
 * OfficeKit
 *
 * Created by François Lamboley on 05/07/2019.
 */

#if !canImport(DirectoryService) || !canImport(OpenDirectory)

public typealias ODRecordOKWrapper = DummyServiceUser

#else

import Foundation
import OpenDirectory

import Email



public struct ODRecordOKWrapper : DirectoryUser {
	
	public typealias IdType = LDAPDistinguishedName
	public typealias PersistentIdType = UUID
	
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
			throw InvalidArgumentError(message: "Cannot create an ODRecordOKWrapper if I don’t have an id or have too many ids in the record. Record attributes: \(attributes)")
		}
		userId = try LDAPDistinguishedName(string: idStr)
		
		let emails = (attributes[kODAttributeTypeEMailAddress] as? [String])?.compactMap{ Email(rawValue: $0) }
		
		persistentId = (attributes[kODAttributeTypeGUID] as? [String])?.onlyElement.flatMap{ UUID(uuidString: $0) }.flatMap{ .set($0) } ?? .unset
		identifyingEmail = emails.flatMap{ .set($0.first) } ?? .unset
		otherEmails = emails.flatMap{ .set(Array($0.dropFirst())) } ?? .unset
		firstName = (attributes[kODAttributeTypeFirstName] as? [String])?.onlyElement.flatMap{ .set($0) } ?? .unset
		lastName = (attributes[kODAttributeTypeLastName] as? [String])?.onlyElement.flatMap{ .set($0) } ?? .unset
	}
	
	public init(id theId: LDAPDistinguishedName, identifyingEmail ie: Email?, otherEmails oe: [Email], firstName fn: String? = nil, lastName ln: String? = nil) {
		userId = theId
		persistentId = .unset
		
		identifyingEmail = .set(ie)
		otherEmails = .set(oe)
		firstName = fn.map{ .set($0) } ?? .unset
		lastName = ln.map{ .set($0) } ?? .unset
	}
	
	public var record: ODRecord?
	
	public var userId: LDAPDistinguishedName
	public var persistentId: RemoteProperty<UUID>
	
	public var identifyingEmail: RemoteProperty<Email?>
	public var otherEmails: RemoteProperty<[Email]>
	
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	
	public let nickname = RemoteProperty<String?>.unsupported
	
}

#endif
