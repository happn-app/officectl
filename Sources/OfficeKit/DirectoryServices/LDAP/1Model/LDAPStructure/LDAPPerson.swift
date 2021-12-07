/*
 * LDAPPerson.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation



/* https://www.ietf.org/rfc/rfc4519.txt */
public class LDAPPerson : LDAPTop {
	
	public static let propNameSN = "sn"
	public static let propNameCN = "cn"
	public static let propNameUserPassword = "userPassword"
	
	public var sn: [String] /* 2.5.4.4 — The surname (family name) of the person */
	public var cn: [String] /* 2.5.4.3 — The common name of the person (typically its full name) */
	
	public var userPassword: String? /* 2.5.4.35 — The password of the user. Can be hashed. */
	
	public convenience init(dnString: String, sn surname: [String], cn commonName: [String]) throws {
		try self.init(dn: LDAPDistinguishedName(string: dnString), sn: surname, cn: commonName)
	}
	
	public init(dn dname: LDAPDistinguishedName, sn surname: [String], cn commonName: [String]) {
		sn = surname
		cn = commonName
		
		super.init(dn: dname)
	}
	
	public override func ldapObject() -> LDAPObject {
		var ret = super.ldapObject()
		ret.attributes[LDAPTop.propNameObjectClass] = [Data("person".utf8)] /* We override the superclass’s value because it is implicit. */
		ret.attributes[LDAPPerson.propNameSN] = sn.map{ Data($0.utf8) }
		ret.attributes[LDAPPerson.propNameCN] = cn.map{ Data($0.utf8) }
		if let pass = userPassword {ret.attributes[LDAPPerson.propNameUserPassword] = [Data(pass.utf8)] }
		return ret
	}
	
}
