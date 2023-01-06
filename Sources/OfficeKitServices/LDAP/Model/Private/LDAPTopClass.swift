/*
 * LDAPTopClass.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation



/* <https://www.ietf.org/rfc/rfc4512.txt> (we have not done all of the attributes). */
enum LDAPTopClass : LDAPClass {
	
	static let name: String = "top"
	static var parents: [LDAPClass.Type] = []
	
	/* The classes of the object. */
	enum ObjectClass : LDAPAttribute {
		
		typealias Value = [String]
		static let attributeDescription: AttributeDescription = .knownDescrAndNumericoid(
			.init(rawValue: "objectClass")!,
			.init(rawValue: "2.5.4.0")!
		)
	}
	
}
