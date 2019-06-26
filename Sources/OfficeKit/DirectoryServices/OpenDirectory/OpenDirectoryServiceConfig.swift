/*
 * OpenDirectoryServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory



public struct OpenDirectoryServiceConfig : OfficeKitServiceConfig {
	
	public static let providerId = "internal_opendirectory"
	
	public var serviceId: String
	public var serviceName: String
	
	public var connectorSettings: OpenDirectoryConnector.Settings
	public var authenticatorSettings: OpenDirectoryRecordAuthenticator.Settings
	
	public init(serviceId id: String, serviceName name: String, connectorSettings c: OpenDirectoryConnector.Settings, authenticatorSettings a: OpenDirectoryRecordAuthenticator.Settings) {
		serviceId = id
		serviceName = name
		
		connectorSettings = c
		authenticatorSettings = a
	}
	
	public init(serviceId id: String, serviceName name: String, genericConfig: GenericConfig) throws {
		let domain = "OpenDirectory Config"
		let hostnameString = try genericConfig.string(for: "server", domain: domain)
		let adminUsernameString = try genericConfig.string(for: "admin_username", domain: domain)
		let adminPasswordString = try genericConfig.string(for: "admin_password", domain: domain)
		let ldapAdminUsernameString = try genericConfig.string(for: "ldap_admin_username", domain: domain)
		let ldapAdminPasswordString = try genericConfig.string(for: "ldap_admin_password", domain: domain)
		
		let connectorSettings = OpenDirectoryConnector.Settings(serverHostname: hostnameString, username: adminUsernameString, password: adminPasswordString, nodeType: ODNodeType(kODNodeTypeAuthentication))
		let authenticatorSettings = OpenDirectoryRecordAuthenticator.Settings(username: ldapAdminUsernameString, password: ldapAdminPasswordString)
		self.init(serviceId: id, serviceName: name, connectorSettings: connectorSettings, authenticatorSettings: authenticatorSettings)
	}
	
}

#endif
