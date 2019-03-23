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
		let yamlLDAPConfig = yamlConfig?["ldap"]
		
		let connectorSettings: LDAPConnector.Settings
		guard let url = (f.getString(name: "ldap-url") ?? yamlLDAPConfig?["url"].string).flatMap({ URL(string: $0) }) else {
			return nil
		}
		if let un = f.getString(name: "ldap-admin-username") ?? yamlLDAPConfig?["admin_username"].string,
			let pass = f.getString(name: "ldap-admin-password") ?? yamlLDAPConfig?["admin_password"].string
		{
			connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3, username: un, password: pass)
		} else {
			connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3)
		}
		
		guard let bdnDic = try OfficectlConfig.stringStringDicFrom(flags: f, yamlConfig: yamlConfig, flagName: "ldap-base-dn-per-domain", yamlName: "base_dn_per_domains") else {
			return nil
		}
		
		let pdnString = f.getString(name: "ldap-people-dn") ?? yamlLDAPConfig?["people_dn"].string
		let adnString =
			f.getString(name: "ldap-admin-groups-dn")?.split(separator: ";").map(String.init) ??
			(try? yamlLDAPConfig?["admin_groups_dn"].array?.map{ y -> String in guard let dn = y.string else {throw InternalError()}; return dn }).flatMap{ $0 } ?? /* Last flatMap on the line should be able to be dropped w/ Swift 5 */
			[]
		
		self.init(connectorSettings: connectorSettings, baseDNPerDomainString: bdnDic, peopleDNString: pdnString, adminGroupsDNString: adnString)
	}
	
}
