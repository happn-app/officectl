/*
 * LDAPConnector+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 19/07/2018.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



extension LDAPConnector {
	
	convenience init(flags f: Flags) throws {
		guard let url = f.getString(name: "ldap-url").flatMap({ URL(string: $0) }) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "A valid ldap-url argument is required for commands dealing with an LDAP"])
		}
		if let un = f.getString(name: "ldap-admin-username"), let pass = f.getString(name: "ldap-admin-password") {
			try self.init(ldapURL: url, protocolVersion: .v3, username: un, password: pass)
		} else {
			try self.init(ldapURL: url, protocolVersion: .v3)
		}
	}
	
}


extension LDAPConnector.Settings : Service {
	
	init?(flags f: Flags) {
		guard let host = f.getString(name: "ldap-host"), let url = URL(string: "ldap://" + host) else {
			return nil
		}
		if let un = f.getString(name: "ldap-admin-username"), let pass = f.getString(name: "ldap-admin-password") {
			self.init(ldapURL: url, protocolVersion: .v3, username: un, password: pass)
		} else {
			self.init(ldapURL: url, protocolVersion: .v3)
		}
	}
	
}
