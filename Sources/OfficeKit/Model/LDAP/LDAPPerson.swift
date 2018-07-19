/*
 * LDAPPerson.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation



/* https://www.ietf.org/rfc/rfc4519.txt */
public class LDAPPerson : LDAPTop {
	
	public var sn: [String] /* 2.5.4.4 — The surname (family name) of the person */
	public var cn: [String] /* 2.5.4.3 — The common name of the person (typically its full name) */
	
	public var userPassword: String?
	
	public init(dn dname: String, sn surname: [String], cn commonName: [String]) {
		sn = surname
		cn = commonName
		
		super.init(dn: dname)
	}
	
	public override func ldapObject() -> LDAPObject {
		var ret = super.ldapObject()
		ret.attributes["objectClass"] = [Data("person".utf8)] /* We override the superclass’s value because it is implicit. */
		ret.attributes["sn"] = sn.map{ Data($0.utf8) }
		ret.attributes["cn"] = cn.map{ Data($0.utf8) }
		return ret
	}
	
}
