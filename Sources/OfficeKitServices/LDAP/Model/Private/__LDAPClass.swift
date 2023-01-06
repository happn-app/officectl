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

protocol LDAPClass {
	
	static var name: String {get}
	static var parents: [LDAPClass.Type] {get}
	
}
