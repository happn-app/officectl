/*
 * LDAPTop.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation



/* https://www.ietf.org/rfc/rfc4512.txt */
public class LDAPTop {
	
	public static let propNameObjectClass = "objectClass"
	
	public var dn: LDAPDistinguishedName
	
	public init(dnString: String) throws {
		dn = try LDAPDistinguishedName(string: dnString)
	}
	
	public init(dn dname: LDAPDistinguishedName) {
		dn = dname
	}
	
	public func ldapObject() -> LDAPObject {
		return LDAPObject(distinguishedName: dn, attributes: [LDAPTop.propNameObjectClass: [Data("top".utf8)]])
	}
	
}
