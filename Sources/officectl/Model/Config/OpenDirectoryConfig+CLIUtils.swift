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



extension OpenDirectoryServiceConfig {
	
	init(flags f: Flags, yamlConfig: Yaml) throws {
		let hostnameString = try yamlConfig.string(for: "server")
		let adminUsernameString = try yamlConfig.string(for: "admin_username")
		let adminPasswordString = try yamlConfig.string(for: "admin_password")
		let ldapAdminUsernameString = try yamlConfig.string(for: "ldap_admin_username")
		let ldapAdminPasswordString = try yamlConfig.string(for: "ldap_admin_password")
		
		let connectorSettings = OpenDirectoryConnector.Settings(serverHostname: hostnameString, username: adminUsernameString, password: adminPasswordString, nodeType: ODNodeType(kODNodeTypeAuthentication))
		let authenticatorSettings = OpenDirectoryRecordAuthenticator.Settings(username: ldapAdminUsernameString, password: ldapAdminPasswordString)
		self.init(connectorSettings: connectorSettings, authenticatorSettings: authenticatorSettings)
	}
	
}

#endif
