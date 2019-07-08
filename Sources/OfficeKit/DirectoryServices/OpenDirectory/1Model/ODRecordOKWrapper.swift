/*
 * ODRecordOKWrapper.swift
 * OfficeKit
 *
 * Created by François Lamboley on 05/07/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation

import OpenDirectory



public struct ODRecordOKWrapper : DirectoryUser {
	
	public typealias UserIdType = LDAPDistinguishedName
	#warning("TODO: Honestly, I don’t know what type the persistent id of an LDAP object is.")
	public typealias PersistentIdType = LDAPDistinguishedName
	
	public init(record r: ODRecord) throws {
		record = r
		
		/* Not great… I’m not even sure the following line doesn’t do blocking IO
		 * on the OpenDirectory Server! But I don’t really care, it’s
		 * OpenDirectory; this Framework is an aberration… */
		guard let idsStr = try r.recordDetails(forAttributes: [kODAttributeTypeMetaRecordName])[kODAttributeTypeMetaRecordName] as? [String], let idStr = idsStr.first, idsStr.count == 1 else {
			throw InvalidArgumentError(message: "Cannot create an ODRecordOKWrapper if I don’t have an id or have too many ids in the record. Record is: \(r)")
		}
		userId = try LDAPDistinguishedName(string: idStr)
		
		#warning("TODO")
		persistentId = .unsupported
		emails = .unsupported
		firstName = .unsupported
		lastName = .unsupported
	}
	
	public init(id theId: LDAPDistinguishedName, emails e: [Email]) {
		userId = theId
		persistentId = .unfetched
		
		emails = .fetched(e)
		firstName = .unfetched
		lastName = .unfetched
	}
	
	public var record: ODRecord?
	
	public var userId: LDAPDistinguishedName
	public var persistentId: RemoteProperty<LDAPDistinguishedName>
	
	public var emails: RemoteProperty<[Email]>
	
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	
	public let nickname = RemoteProperty<String?>.unsupported
	
}

#endif
