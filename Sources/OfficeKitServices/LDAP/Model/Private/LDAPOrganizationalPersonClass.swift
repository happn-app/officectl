/*
 * LDAPOrganizationalPersonClass.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation



/* <https://www.ietf.org/rfc/rfc4519.txt> (we have not done all of the attributes). */
enum LDAPOrganizationalPersonClass : LDAPClass {
	
	static let name: String = "organizationalPerson"
	static let directParents: [LDAPClass.Type] = [LDAPPersonClass.self]
	
}
