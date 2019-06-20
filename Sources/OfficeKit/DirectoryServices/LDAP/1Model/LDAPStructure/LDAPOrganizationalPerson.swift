/*
 * LDAPOrganizationalPerson.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation



/* https://www.ietf.org/rfc/rfc4519.txt */
public class LDAPOrganizationalPerson : LDAPPerson {
	
	public override func ldapObject() -> LDAPObject {
		var ret = super.ldapObject()
		ret.attributes["objectClass"] = [Data("organizationalPerson".utf8)] /* We override the superclass’s value because it is implicit. */
		return ret
	}
	
}
