/*
 * OpenDirectoryUser.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation

import OfficeKit2



/* We do not use ODRecord because they cannot be created without either retrieving an existing record from a node or creating a new record in a node. */
public struct OpenDirectoryUser : Sendable {
	
	/* kODAttributeTypeMetaRecordName
	 * We do not store it in properties because we want it to never be nil. */
	public var id: LDAPDistinguishedName
	/** All of the properties of the user except for its id. */
	public var properties = [String: OpenDirectoryAttributeValue]()
	
	public init(id: LDAPDistinguishedName) {
		self.id = id
	}
	
}
