/*
 * LDAPUser.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import OfficeKit2



/* We do not use ODRecord because they cannot be created without either retrieving an existing record from a node or creating a new record in a node. */
public struct LDAPUser : Sendable, Codable {
	
	public internal(set) var id: LDAPDistinguishedName
	public internal(set) var record: LDAPRecord
	
}
