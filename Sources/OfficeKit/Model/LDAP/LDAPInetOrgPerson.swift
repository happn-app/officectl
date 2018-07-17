/*
 * LDAPInetOrgPerson.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



/* https://www.ietf.org/rfc/rfc2798.txt */
public class LDAPInetOrgPerson : LDAPOrganizationalPerson {
	
	public var givenName: [String]? /* 2.5.4.42 — The names that are not the surnames of the person */
	
	public var mail: [Email]? /* 0.9.2342.19200300.100.1.3 — The email of the person */
	
}
