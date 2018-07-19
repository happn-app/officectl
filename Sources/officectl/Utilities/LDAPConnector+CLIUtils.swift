/*
 * LDAPConnector+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 19/07/2018.
 */

import Foundation

import Guaka

import OfficeKit



extension LDAPConnector {
	
	convenience init(flags f: Flags) throws {
		guard let host = f.getString(name: "ldap-host") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The ldap-host argument is required for commands dealing with an LDAP"])
		}
		guard let url = URL(string: "ldap://" + host) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid host for LDAP"])
		}
		if let un = f.getString(name: "ldap-admin-username"), let pass = f.getString(name: "ldap-admin-password") {
			try self.init(ldapURL: url, protocolVersion: .v3, username: un, password: pass)
		} else {
			try self.init(ldapURL: url, protocolVersion: .v3)
		}
	}
	
}
