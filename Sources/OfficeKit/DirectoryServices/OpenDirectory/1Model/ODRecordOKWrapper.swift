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
	
	public init(record r: ODRecord) throws {
		record = r
		
		/* Not great… I’m not even sure the following line doesn’t do blocking IO
		 * on the OpenDirectory Server! But I don’t really care, it’s
		 * OpenDirectory; this Framework is an aberration… */
		guard let idsStr = try r.recordDetails(forAttributes: [kODAttributeTypeMetaRecordName])[kODAttributeTypeMetaRecordName] as? [String], let idStr = idsStr.first, idsStr.count == 1 else {
			throw InvalidArgumentError(message: "Cannot create an ODRecordOKWrapper if I don’t have an id or have too many ids in the record. Record is: \(r)")
		}
		id = try LDAPDistinguishedName(string: idStr)
		
		#warning("TODO")
		emails = .unfetched
		firstName = .unfetched
		lastName = .unfetched
	}
	
	public init(id theId: LDAPDistinguishedName, emails e: [Email], firstName fn: String?, lastName ln: String?) {
		id = theId
		
		emails = .fetched(e)
		firstName = .fetched(fn)
		lastName = .fetched(ln)
	}
	
	public typealias IdType = LDAPDistinguishedName
	
	public var record: ODRecord?
	
	public var id: LDAPDistinguishedName
	public var emails: RemoteProperty<[Email]>
	
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	
	public let nickname = RemoteProperty<String?>.unsupported
	
}

#endif
