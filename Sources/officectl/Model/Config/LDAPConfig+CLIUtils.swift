/*
 * LDAPConfig+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 19/07/2018.
 */

import Foundation

import Guaka
import Yaml

import OfficeKit



extension LDAPServiceConfig {
	
	init(flags f: Flags, yamlConfig: Yaml) throws {
		let url = try yamlConfig.url(for: "url")
		let adminUsername = try yamlConfig.optionalString(for: "admin_username")
		let adminPassword = try yamlConfig.optionalString(for: "admin_password")
		
		let bdnDic    = try yamlConfig.stringStringDic(for: "base_dn_per_domains")
		let pdnString = try yamlConfig.optionalString(for: "people_dn")
		let adnString = try yamlConfig.optionalStringArray(for: "admin_groups_dn") ?? []
		
		
		let connectorSettings: LDAPConnector.Settings
		switch (adminUsername, adminPassword) {
		case (.some, .none), (.none, .some):
			throw InvalidArgumentError(message: "Invalid config in yaml: neither both or none of admin_username & admin_password defined in an LDAP config")
			
		case (.none, .none):
			connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3)
			
		case let (username?, password?):
			connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3, username: username, password: password)
		}
		
		try self.init(connectorSettings: connectorSettings, baseDNPerDomainString: bdnDic, peopleDNString: pdnString, adminGroupsDNString: adnString)
	}
	
}
