/*
 * __LDAPClass.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import UnwrapOrThrow

import OfficeKit2


/* Note:
 * For now we have decided to declare the classes and attributes directly in code.
 * This is great for convenience access to some attributes in a record.
 * However it is not flexible.
 *
 * The next step would probably to read the LDAP models directly, which would allow validation of attributes directly
 * I have never done that; I have currently no idea how it truly work and how feasible it is. */

/**
 The dictionary of known classes in the LDAP module.
 Maybe some day we’ll use the runtime to get the list; for now it’s manual.
 
 - Important: This property must be updated when a new object conforming to LDAPClass is created. */
let knownClasses: [String: LDAPClass.Type] = [
	LDAPTopClass.name: LDAPTopClass.self,
	LDAPPersonClass.name: LDAPPersonClass.self,
	LDAPOrganizationalPersonClass.name: LDAPOrganizationalPersonClass.self,
	LDAPInetOrgPersonClass.name: LDAPInetOrgPersonClass.self
]


protocol LDAPClass {
	
	/* ⚠️ Important!
	 * Don’t forget to update knownClasses when new objects conforming to this protocol are created. */
	
	static var name: String {get}
	static var directParents: [LDAPClass.Type] {get}
	
}


extension LDAPClass {
	
	static var allParents: [LDAPClass.Type] {
		return directParents.flatMap{ [$0] + $0.allParents }
	}
	
}
