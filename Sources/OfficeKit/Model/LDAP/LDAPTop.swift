/*
 * LDAPTop.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation



/* https://www.ietf.org/rfc/rfc4512.txt */
public class LDAPTop {
	
	public var dn: String
	
	public init(dn dname: String) {
		dn = dname
	}
	
	public func ldapObject() -> LDAPObject {
		return LDAPObject(distinguishedName: dn, attributes: ["objectClass": [Data("top".utf8)]])
	}
	
}
