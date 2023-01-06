/*
 * LDAPInetOrgPersonClass.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import Email
import UnwrapOrThrow



/* <https://www.ietf.org/rfc/rfc2798.txt> (we have not done all of the attributes). */
enum LDAPInetOrgPersonClass : LDAPClass {
	
	static let name: String = "inetOrgPerson"
	static var parents: [LDAPClass.Type] = [LDAPOrganizationalPersonClass.self]
	
	enum UID : LDAPAttribute {
		
		typealias Value = String /* I _think_ this cannot be an array. */
		static let attributeDescription: AttributeDescription = .init(
			.init(rawValue: "uid")! /* Note: RFC 1274 uses the identifier "userid" <http://www.oid-info.com/get/0.9.2342.19200300.100.1.1> */,
			.init(rawValue: "0.9.2342.19200300.100.1.1")!
		)
	}
	
	/* Usually the first names. */
	enum GivenName : LDAPAttribute {
		
		typealias Value = [String] /* I _think_ this can be an array. */
		static let attributeDescription: AttributeDescription = .init(
			.init(rawValue: "givenName")!,
			.init(rawValue: "2.5.4.42")!
		)
		
	}
	
	enum Mail : LDAPAttribute {
		
		typealias Value = [Email]
		static let attributeDescription: AttributeDescription = .init(
			.init(rawValue: "mail")! /* Note: RFC 1274 uses the identifier "rfc822Mailbox" <http://www.oid-info.com/get/0.9.2342.19200300.100.1.3> */,
			.init(rawValue: "0.9.2342.19200300.100.1.3")!
		)
		
		static func value(from ldapValue: [Data]) throws -> [Email] {
			return try stringValues(for: ldapValue).map{ try Email(rawValue: $0) ?! Err.valueIsNotEmails }
		}
		
	}
	
}
