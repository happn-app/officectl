/*
 * LDAPTopClass.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import OfficeKit



/* <https://www.ietf.org/rfc/rfc4512.txt> (we have not done all of the attributes). */
enum LDAPTopClass : LDAPClass {
	
	static let name: String = "top"
	static let directParents: [LDAPClass.Type] = []
	
	/* The classes of the object. */
	enum ObjectClass : LDAPAttribute {
		
		typealias Value = [String]
		
		static let objectClass: LDAPClass.Type = LDAPTopClass.self
		
		static let descr = LDAPObjectID.Descr(rawValue: "objectClass")!
		static let numericoid = LDAPObjectID.Numericoid(rawValue: "2.5.4.0")!
		
	}
	
}
