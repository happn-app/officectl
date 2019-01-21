/*
 * LDAPConfig+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 19/07/2018.
 */

import Foundation

import Guaka
import Vapor
import Yaml

import OfficeKit



extension OfficeKitConfig.LDAPConfig {
	
	init?(flags f: Flags, yamlConfig: Yaml?) throws {
		let connectorSettings: LDAPConnector.Settings
		guard let url = f.getString(name: "ldap-url").flatMap({ URL(string: $0) }) else {
			return nil
		}
		if let un = f.getString(name: "ldap-admin-username"), let pass = f.getString(name: "ldap-admin-password") {
			connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3, username: un, password: pass)
		} else {
			connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3)
		}
		
		guard let bdnString = f.getString(name: "ldap-base-dn") else {return nil}
		let pdnString = f.getString(name: "ldap-people-dn")
		
		self.init(connectorSettings: connectorSettings, baseDNString: bdnString, peopleDNString: pdnString)
	}
	
}
