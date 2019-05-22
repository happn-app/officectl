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
	
	init?(flags f: Flags, yamlConfig: Yaml) throws {
		guard let yamlLDAPConfig = yamlConfig["ldap"].dictionary else {return nil}
		
		let connectorSettings: LDAPConnector.Settings
		guard let url = yamlLDAPConfig["url"]?.string.flatMap({ URL(string: $0) }) else {
			return nil
		}
		if let un = yamlLDAPConfig["admin_username"]?.string, let pass = yamlLDAPConfig["admin_password"]?.string {
			connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3, username: un, password: pass)
		} else {
			connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3)
		}
		
		guard let bdnDic = try? OfficectlConfig.stringStringDicFrom(yamlConfig: Yaml.dictionary(yamlLDAPConfig), yamlName: "base_dn_per_domains") else {
			return nil
		}
		
		let pdnString = yamlLDAPConfig["people_dn"]?.string
		let adnString = (try? OfficectlConfig.stringArrayFrom(yamlConfig: yamlLDAPConfig, yamlName: "admin_groups_dn")) ?? []
		
		self.init(connectorSettings: connectorSettings, baseDNPerDomainString: bdnDic, peopleDNString: pdnString, adminGroupsDNString: adnString)
	}
	
}
