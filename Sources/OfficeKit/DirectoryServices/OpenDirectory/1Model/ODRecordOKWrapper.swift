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
		
		/* Not great… I’m not even sure the following line doesn’t do blocking IO
		 * on the OpenDirectory Server! But I don’t really care, it’s
		 * OpenDirectory; this Framework is an aberration… */
		#warning("TODO: After reading the doc, it seems that passing a nil attributes list will return what’s in the cache and shouldn’t do IO.")
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
