/*
 * LDAPInetOrgPerson.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



/* https://www.ietf.org/rfc/rfc2798.txt */
public class LDAPInetOrgPerson : LDAPOrganizationalPerson {
	
	public var uid: String? /* 0.9.2342.19200300.100.1.1 — The UID of the person */
	
	public var givenName: [String]? /* 2.5.4.42 — The names that are not the surnames of the person */
	
	public var mail: [Email]? /* 0.9.2342.19200300.100.1.3 — The email of the person */
	
	public override func ldapObject() -> LDAPObject {
		var ret = super.ldapObject()
		ret.attributes["objectClass"] = [Data("inetOrgPerson".utf8)] /* We override the superclass’s value because it is implicit. */
		if let gn = givenName {ret.attributes["givenName"] = gn.map{ Data($0.utf8) }}
		if let m = mail {ret.attributes["mail"] = m.map{ Data($0.stringValue.utf8) }}
		if let u = uid {ret.attributes["uid"] = [Data(u.utf8)]}
		return ret
	}
	
}
