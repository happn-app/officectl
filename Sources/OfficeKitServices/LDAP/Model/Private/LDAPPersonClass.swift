/*
 * LDAPPersonClass.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import OfficeKit2



/* <https://www.ietf.org/rfc/rfc4519.txt> (we have not done all of the attributes). */
enum LDAPPersonClass : LDAPClass {
	
	static let name: String = "person"
	static let directParents: [LDAPClass.Type] = [LDAPTopClass.self]
	
	/* The family name of the person. */
	enum Surname : LDAPAttribute {
		
		typealias Value = [String] /* RFC seems to say this can be an array. */
		
		static let objectClass: LDAPClass.Type = LDAPPersonClass.self
		
		static let descr = LDAPObjectID.Descr(rawValue: "sn")!
		static let numericoid = LDAPObjectID.Numericoid(rawValue: "2.5.4.4")!
		
	}
	
	/* The full name of the person. */
	enum CommonName : LDAPAttribute {
		
		typealias Value = [String] /* RFC seems to say this can be an array. */
		
		static let objectClass: LDAPClass.Type = LDAPPersonClass.self
		
		static let descr = LDAPObjectID.Descr(rawValue: "cn")!
		static let numericoid = LDAPObjectID.Numericoid(rawValue: "2.5.4.3")!
		
	}
	
	/* Can be hashed, but RFC says password are stored unencrypted… */
	enum UserPassword : LDAPAttribute {
		
		typealias Value = [String] /* RFC seems to say this can be an array. */
		
		static let objectClass: LDAPClass.Type = LDAPPersonClass.self
		
		static let descr = LDAPObjectID.Descr(rawValue: "userPassword")!
		static let numericoid = LDAPObjectID.Numericoid(rawValue: "2.5.4.35")!
		
	}
	
}
