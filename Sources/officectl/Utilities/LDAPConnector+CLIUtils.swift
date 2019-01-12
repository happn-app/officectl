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



extension LDAPConnector.Settings {
	
	init?(flags f: Flags) {
		guard let url = f.getString(name: "ldap-url").flatMap({ URL(string: $0) }) else {
			return nil
		}
		if let un = f.getString(name: "ldap-admin-username"), let pass = f.getString(name: "ldap-admin-password") {
			self.init(ldapURL: url, protocolVersion: .v3, username: un, password: pass)
		} else {
			self.init(ldapURL: url, protocolVersion: .v3)
		}
	}
	
}

extension OfficeKitConfig.LDAPConfig {
	
	init?(flags f: Flags) {
		guard let connectorSettings = LDAPConnector.Settings(flags: f) else {return nil}
		guard let bdnString = f.getString(name: "ldap-base-dn") else {return nil}
		let pdnString = f.getString(name: "ldap-people-dn")
		
		self.init(connectorSettings: connectorSettings, baseDNString: bdnString, peopleDNString: pdnString)
	}
	
}


extension LDAPConnector {
	
	convenience init(flags f: Flags) throws {
		guard let settings = LDAPConnector.Settings(flags: f) else {
			throw InvalidArgumentError(message: "Cannot load LDAP settings from command line")
		}
		try self.init(key: settings)
	}
	
}
