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
	public var baseDNPerDomain: [String: LDAPDistinguishedName]
	public var peopleBaseDNPerDomain: [String: LDAPDistinguishedName]?
	
	public var allBaseDNs: Set<LDAPDistinguishedName> {
		return Set(baseDNPerDomain.values)
	}
	
	public var allDomains: Set<String> {
		return Set(baseDNPerDomain.keys)
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, connectorSettings c: OpenDirectoryConnector.Settings, authenticatorSettings a: OpenDirectoryRecordAuthenticator.Settings, baseDNPerDomainString: [String: String], peopleDNString: String?) throws {
		let bdn = try baseDNPerDomainString.mapValues{ try LDAPDistinguishedName(string: $0) }
		baseDNPerDomain = bdn
		peopleBaseDNPerDomain = try peopleDNString.flatMap{ peopleDNString -> [String: LDAPDistinguishedName] in
			guard !peopleDNString.isEmpty else {return bdn}
			let pdnc = try LDAPDistinguishedName(string: peopleDNString)
			return bdn.mapValues{ pdnc + $0 }
		}
		
		precondition(id != "email" && !id.contains(":"))
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
		
		let bdnDic    = try genericConfig.stringStringDic(for: "base_dn_per_domains", domain: domain)
		let pdnString = try genericConfig.optionalString(for: "people_dn", domain: domain)
		
		let connectorSettings = OpenDirectoryConnector.Settings(serverHostname: hostnameString, username: adminUsernameString, password: adminPasswordString, nodeType: ODNodeType(kODNodeTypeAuthentication))
		let authenticatorSettings = OpenDirectoryRecordAuthenticator.Settings(username: ldapAdminUsernameString, password: ldapAdminPasswordString)
		try self.init(providerId: pId, serviceId: id, serviceName: name, connectorSettings: connectorSettings, authenticatorSettings: authenticatorSettings, baseDNPerDomainString: bdnDic, peopleDNString: pdnString)
	}
	
}

#endif
