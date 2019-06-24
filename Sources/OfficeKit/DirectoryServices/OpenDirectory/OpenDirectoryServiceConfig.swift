/*
 * OpenDirectoryServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory



public struct OpenDirectoryServiceConfig {
	
	public var connectorSettings: OpenDirectoryConnector.Settings
	public var authenticatorSettings: OpenDirectoryRecordAuthenticator.Settings
	
	public init(connectorSettings c: OpenDirectoryConnector.Settings, authenticatorSettings a: OpenDirectoryRecordAuthenticator.Settings) {
		connectorSettings = c
		authenticatorSettings = a
	}
	
//	public init(dictionary: [String : Any?]) throws {
//		let domain = "OpenDirectoryConfig"
//		let server: String                  = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "server",              domain: domain)
//		let adminUsername: String           = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "admin_username",      domain: domain)
//		let adminPassword: String           = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "admin_password",      domain: domain)
//		let ldapAdminUsernameString: String = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "ldap_admin_username", domain: domain)
//		let ldapAdminPasswordString: String = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "ldap_admin_password", domain: domain)
//		
//		let connectorSettings = OpenDirectoryConnector.Settings(serverHostname: server, username: adminUsername, password: adminPassword, nodeType: ODNodeType(kODNodeTypeAuthentication))
//		let authenticatorSettings = OpenDirectoryRecordAuthenticator.Settings(username: ldapAdminUsernameString, password: ldapAdminPasswordString)
//		self.init(connectorSettings: connectorSettings, authenticatorSettings: authenticatorSettings)
//	}
	
}

#endif
