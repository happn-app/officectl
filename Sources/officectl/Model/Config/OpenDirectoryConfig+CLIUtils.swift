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
	
	init?(flags f: Flags, yamlConfig: Yaml) throws {
		guard let yamlOpenDirectoryConfig = yamlConfig["opendirectory"].dictionary else {return nil}
		
		guard let hostnameString = yamlOpenDirectoryConfig["server"]?.string else {return nil}
		guard let adminUsernameString = yamlOpenDirectoryConfig["admin_username"]?.string else {return nil}
		guard let adminPasswordString = yamlOpenDirectoryConfig["admin_password"]?.string else {return nil}
		guard let ldapAdminUsernameString = yamlOpenDirectoryConfig["ldap_admin_username"]?.string else {return nil}
		guard let ldapAdminPasswordString = yamlOpenDirectoryConfig["ldap_admin_password"]?.string else {return nil}
		
		let connectorSettings = OpenDirectoryConnector.Settings(serverHostname: hostnameString, username: adminUsernameString, password: adminPasswordString, nodeType: ODNodeType(kODNodeTypeAuthentication))
		let authenticatorSettings = OpenDirectoryRecordAuthenticator.Settings(username: ldapAdminUsernameString, password: ldapAdminPasswordString)
		self.init(connectorSettings: connectorSettings, authenticatorSettings: authenticatorSettings)
	}
	
}

#endif
