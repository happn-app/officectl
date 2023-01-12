/*
 * LDAPObject.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import OfficeKit



/* We do not use ODRecord because they cannot be created without either retrieving an existing record from a node or creating a new record in a node. */
public struct LDAPObject : Sendable, Codable {
	
	public internal(set) var id: LDAPDistinguishedName
	public internal(set) var record: LDAPRecord
	
	public var allObjectClasses: Set<String>? {
		return record.allObjectClasses
	}
	
	public var objectClassesInRecord: [String]? {
		return record.objectClasses
	}
	
	internal init(forAnyObjectTypeWith id: LDAPDistinguishedName, record: LDAPRecord) {
		self.id = id
		self.record = record
	}
	
}
