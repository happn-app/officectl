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
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var connectorSettings: OpenDirectoryConnector.Settings
	public var authenticatorSettings: OpenDirectoryRecordAuthenticator.Settings
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, connectorSettings c: OpenDirectoryConnector.Settings, authenticatorSettings a: OpenDirectoryRecordAuthenticator.Settings) {
		providerId = pId
		serviceId = id
		serviceName = name
		
		connectorSettings = c
		authenticatorSettings = a
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "OpenDirectory Config"
		let hostnameString = try genericConfig.string(for: "server", domain: domain)
		let adminUsernameString = try genericConfig.string(for: "admin_username", domain: domain)
		let adminPasswordString = try genericConfig.string(for: "admin_password", domain: domain)
		let ldapAdminUsernameString = try genericConfig.string(for: "ldap_admin_username", domain: domain)
		let ldapAdminPasswordString = try genericConfig.string(for: "ldap_admin_password", domain: domain)
		
		let connectorSettings = OpenDirectoryConnector.Settings(serverHostname: hostnameString, username: adminUsernameString, password: adminPasswordString, nodeType: ODNodeType(kODNodeTypeAuthentication))
		let authenticatorSettings = OpenDirectoryRecordAuthenticator.Settings(username: ldapAdminUsernameString, password: ldapAdminPasswordString)
		self.init(providerId: pId, serviceId: id, serviceName: name, connectorSettings: connectorSettings, authenticatorSettings: authenticatorSettings)
	}
	
}

#endif
