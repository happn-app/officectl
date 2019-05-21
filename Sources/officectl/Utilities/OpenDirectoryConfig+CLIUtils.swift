/*
 * OpenDirectoryConfig+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 21/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import Guaka
import Yaml

import OfficeKit



extension OfficeKitConfig.OpenDirectoryConfig {
	
	init?(flags f: Flags, yamlConfig: Yaml?) throws {
		let yamlOpenDirectoryConfig = yamlConfig?["opendirectory"]
		
		guard let hostnameString = f.getString(name: "od-server") ?? yamlOpenDirectoryConfig?["server"].string else {return nil}
		guard let adminUsernameString = f.getString(name: "od-admin-username") ?? yamlOpenDirectoryConfig?["admin_username"].string else {return nil}
		guard let adminPasswordString = f.getString(name: "od-admin-password") ?? yamlOpenDirectoryConfig?["admin_password"].string else {return nil}
		guard let ldapAdminUsernameString = f.getString(name: "od-ldap-admin-username") ?? yamlOpenDirectoryConfig?["ldap_admin_username"].string else {return nil}
		guard let ldapAdminPasswordString = f.getString(name: "od-ldap-admin-password") ?? yamlOpenDirectoryConfig?["ldap_admin_password"].string else {return nil}
		
		let connectorSettings = OpenDirectoryConnector.Settings(serverHostname: hostnameString, username: adminUsernameString, password: adminPasswordString, nodeType: ODNodeType(kODNodeTypeAuthentication))
		let authenticatorSettings = OpenDirectoryRecordAuthenticator.Settings(username: ldapAdminUsernameString, password: ldapAdminPasswordString)
		self.init(connectorSettings: connectorSettings, authenticatorSettings: authenticatorSettings)
	}
	
}

#endif
