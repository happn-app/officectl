/*
 * OpenDirectoryUser.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation
import OpenDirectory

import OfficeKit2



/* We do not use ODRecord because they cannot be created without either retrieving an existing record from a node or creating a new record in a node. */
public struct OpenDirectoryUser : Sendable, Codable {
	
	public static let recordType: String = kODRecordTypeUsers
	
	/* kODAttributeTypeMetaRecordName
	 * We do not store it in properties because we want it to never be nil. */
	public var id: LDAPDistinguishedName
	/** All of the properties of the user except for its id. */
	public var properties = [String: OpenDirectoryAttributeValue]()
	
	public init(id: LDAPDistinguishedName, groupID: String = "20", nfsHomeDirectory: String? = "/dev/null", shell: String? = "/usr/bin/false") {
		self.id = id
		properties[kODAttributeTypePrimaryGroupID] = .string(groupID)
		if let shell            {properties[kODAttributeTypeUserShell]        = .string(shell)}
		if let nfsHomeDirectory {properties[kODAttributeTypeNFSHomeDirectory] = .string(nfsHomeDirectory)}
	}
	
	/**
	 Initialiazes an ``OpenDirectoryUser`` with an ODRecord. */
	@ODActor
	internal init(record: ODRecord) throws {
		guard record.recordType == Self.recordType else {
			/* Invalid init of OpenDirectoryUser. */
			throw Err.internalError
		}
		/* This should not throw ever because we’re asking for the attributes already in memory (nil list). */
		guard let attributes = try record.recordDetails(forAttributes: nil) as? [String: Any] else {
			/* We believe recordDetails(forAttributes:) actually returns a [String: Any], not a [AnyHashable: Any] but that because of OpenDirectory not being updated the type is incorrect. */
			throw Err.internalError
		}
		
		self.properties = try attributes.mapValues{ try OpenDirectoryAttributeValue(any: $0) }
		
		guard let idStr = properties[kODAttributeTypeMetaRecordName]?.asString else {
			/* Getting a record without a meta record name is possible, but we do everything we can to avoid that. */
			throw Err.internalError
		}
		properties.removeValue(forKey: kODAttributeTypeMetaRecordName)
		
		self.id = try LDAPDistinguishedName(string: idStr)
		
		_record.wrappedValue = record
	}
	
	/* With the OpenDirectory framework, unless I’m mistaken, to change a record one *must* have the an ODRecord object representing the current record.
	 * To avoid fetching the record for each modification when we already have fetched it, we keep a cached version of it.
	 * Because ODRecord is (presumably) not thread safe, we confine it to an actor.
	 *
	 * I do not declare this as “`@ODObjectWrapper var record: ODRecord?`” because
	 *   1. For semi-explained reasons if I do this the struct does not automatically conforms to Codable.
	 *      This kind of makes sense as the wrapper variable is not optional.
	 *      However setting an initial value (“`@ODObjectWrapper var record: ODRecord? = nil`”) does not solve the issue.
	 *      It might be an oversight of the automatic Codable conformance, but honestly I’m not sure.
	 *   2. For fully unexplained reasons, using the wrapper seems to remove some concurrency protections.
	 *      With the wrapper, when setting _record.wrappedValue in the init while removing @ODActor does not seem to be an issue… which is unexpected. */
	internal var _record: ODObjectWrapper<ODRecord?> = .init()
	
	/**
	 Returns the full name computed from first name and last name, whether full name is set or not.
	 If there are no first name nor last name, we return a static string. */
	internal var computedFullName: String {
		let firstAndLastName = [oU_firstName, oU_lastName].compactMap{ $0 }
		guard !firstAndLastName.isEmpty else {
			return "<Unknown Name>"
		}
		return firstAndLastName.joined(separator: " ")
	}
	
	private enum CodingKeys : CodingKey {
		case id
		case properties
	}
	
}
