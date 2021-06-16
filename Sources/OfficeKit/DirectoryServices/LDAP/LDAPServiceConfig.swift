/*
 * LDAPServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import GenericStorage



public struct LDAPServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	public let isHelperService = false
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var connectorSettings: LDAPConnector.Settings
	public var adminGroupsDN: [LDAPDistinguishedName]
	public var baseDNs: LDAPBaseDNs
	
	/**
	- parameter peopleDNString: The DN for the people, **relative to the base
	DN**. This is a different than the `peopleBaseDN` var in this struct, as
	the var contains the full people DN. */
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: LDAPConnector.Settings, baseDNPerDomainString: [String: String], peopleDNString: String?, adminGroupsDNString: [String]) throws {
		let adn = try adminGroupsDNString.map{ try LDAPDistinguishedName(string: $0) }
		let bdn = try LDAPBaseDNs(baseDNPerDomainString: baseDNPerDomainString, peopleDNString: peopleDNString)
		
		self.init(providerId: pId, serviceId: id, serviceName: name, mergePriority: p, connectorSettings: c, baseDNs: bdn, adminGroupsDN: adn)
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: LDAPConnector.Settings, baseDNs bdn: LDAPBaseDNs, adminGroupsDN agdn: [LDAPDistinguishedName]) {
		precondition(id != "invalid" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		mergePriority = p
		
		connectorSettings = c
		adminGroupsDN = agdn
		baseDNs = bdn
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		
		let url = try keyedConfig.url(forKey: "url", currentKeyPath: domain)
		let startTLS = try keyedConfig.optionalBool(forKey: "start_tls", currentKeyPath: domain) ?? false
		let caCertFile = try keyedConfig.optionalString(forKey: "ca_cert_file", currentKeyPath: domain)
		let adminUsername = try keyedConfig.optionalString(forKey: "admin_username", currentKeyPath: domain)
		let adminPassword = try keyedConfig.optionalString(forKey: "admin_password", currentKeyPath: domain)
		
		let bdnDic    = try keyedConfig.dictionaryOfStrings(forKey: "base_dn_per_domains", currentKeyPath: domain)
		let pdnString = try keyedConfig.optionalString(forKey: "people_dn", currentKeyPath: domain)
		let adnString = try keyedConfig.optionalArrayOfStrings(forKey: "officectl_admin_groups_dn", currentKeyPath: domain) ?? []
		
		let caCertFileURL = caCertFile.flatMap{ URL(fileURLWithPath: $0, isDirectory: false, relativeTo: baseURL) }
		
		let connectorSettings: LDAPConnector.Settings
		switch (adminUsername, adminPassword) {
		case (.none, .none):             connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3, startTLS: startTLS, caCertFile: caCertFileURL)
		case let (username?, password?): connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3, startTLS: startTLS, caCertFile: caCertFileURL, username: username, password: password)
		case (.some, .none), (.none, .some):
			throw InvalidArgumentError(message: "Invalid config in yaml: neither both or none of admin_username & admin_password defined in an LDAP config")
		}
		
		try self.init(providerId: pId, serviceId: id, serviceName: name, mergePriority: p, connectorSettings: connectorSettings, baseDNPerDomainString: bdnDic, peopleDNString: pdnString, adminGroupsDNString: adnString)
	}
	
}
