/*
 * LDAPPersonClass.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation



/* <https://www.ietf.org/rfc/rfc4519.txt> (we have not done all of the attributes). */
enum LDAPPersonClass : LDAPClass {
	
	static let name: String = "person"
	static var parents: [LDAPClass.Type] = [LDAPTopClass.self]
	
	/* The family name of the person. */
	enum Surname : LDAPAttribute {
		
		typealias Value = [String] /* RFC seems to say this can be an array. */
		static let attributeDescription: AttributeDescription = .knownDescrAndNumericoid(
			.init(rawValue: "sn")!,
			.init(rawValue: "2.5.4.4")!
		)
	}
	
	/* The full name of the person. */
	enum CommonName : LDAPAttribute {
		
		typealias Value = [String] /* RFC seems to say this can be an array. */
		static let attributeDescription: AttributeDescription = .knownDescrAndNumericoid(
			.init(rawValue: "cn")!,
			.init(rawValue: "2.5.4.3")!
		)
	}
	
	/* Can be hashed, but RFC says password are stored unencrypted… */
	enum UserPassword : LDAPAttribute {
		
		typealias Value = [String] /* RFC seems to say this can be an array. */
		static let attributeDescription: AttributeDescription = .knownDescrAndNumericoid(
			.init(rawValue: "userPassword")!,
			.init(rawValue: "2.5.4.35")!
		)
	}
	
}
