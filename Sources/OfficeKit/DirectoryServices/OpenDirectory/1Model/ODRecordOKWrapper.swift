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



public struct ODRecordOKWrapper : DirectoryUser {
	
	public typealias UserIdType = LDAPDistinguishedName
	public typealias PersistentIdType = UUID
	
	public init(record r: ODRecord) throws {
		record = r
		
		/* Is this making IO? Who knows… But it shouldn’t be; doc says if
		 * attributes is nil the method returns what’s in the cache. */
		let attributes = try r.recordDetails(forAttributes: nil)
		guard let idStr = (attributes[kODAttributeTypeMetaRecordName] as? [String])?.onlyElement else {
			throw InvalidArgumentError(message: "Cannot create an ODRecordOKWrapper if I don’t have an id or have too many ids in the record. Record is: \(r)")
		}
		userId = try LDAPDistinguishedName(string: idStr)
		
		persistentId = (attributes[kODAttributeTypeGUID] as? [String])?.onlyElement.flatMap{ UUID($0) }.flatMap{ .set($0) } ?? .unset
		emails = (try? (attributes[kODAttributeTypeEMailAddress] as? [String])?.compactMap{ try nil2throw(Email(string: $0)) }).flatMap{ .set($0) } ?? .unset
		firstName = (attributes[kODAttributeTypeFirstName] as? [String])?.onlyElement.flatMap{ .set($0) } ?? .unset
		lastName = (attributes[kODAttributeTypeLastName] as? [String])?.onlyElement.flatMap{ .set($0) } ?? .unset
	}
	
	public init(id theId: LDAPDistinguishedName, emails e: [Email], firstName fn: String? = nil, lastName ln: String? = nil) {
		userId = theId
		persistentId = .unset
		
		emails = .set(e)
		firstName = fn.map{ .set($0) } ?? .unset
		lastName = ln.map{ .set($0) } ?? .unset
	}
	
	public var record: ODRecord?
	
	public var userId: LDAPDistinguishedName
	public var persistentId: RemoteProperty<UUID>
	
	public var emails: RemoteProperty<[Email]>
	
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	
	public let nickname = RemoteProperty<String?>.unsupported
	
}

#endif
