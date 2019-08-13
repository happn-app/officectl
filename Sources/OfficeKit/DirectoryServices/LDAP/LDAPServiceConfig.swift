/*
 * LDAPServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation



public struct LDAPServiceConfig : OfficeKitServiceConfig {
	
	public var global: GlobalConfig
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var connectorSettings: LDAPConnector.Settings
	public var baseDNPerDomain: [String: LDAPDistinguishedName]
	public var peopleBaseDNPerDomain: [String: LDAPDistinguishedName]?
	public var adminGroupsDN: [LDAPDistinguishedName]
	
	public var allBaseDNs: Set<LDAPDistinguishedName> {
		return Set(baseDNPerDomain.values)
	}
	
	public var allDomains: Set<String> {
		return Set(baseDNPerDomain.keys)
	}
	
	/**
	- parameter peopleDNString: The DN for the people, **relative to the base
	DN**. This is a different than the `peopleBaseDN` var in this struct, as
	the var contains the full people DN. */
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, connectorSettings c: LDAPConnector.Settings, baseDNPerDomainString: [String: String], peopleDNString: String?, adminGroupsDNString: [String]) throws {
		let adn = try adminGroupsDNString.map{ try LDAPDistinguishedName(string: $0) }
		let bdn = try baseDNPerDomainString.mapValues{ try LDAPDistinguishedName(string: $0) }
		
		let pdn = try peopleDNString.flatMap{ peopleDNString -> [String: LDAPDistinguishedName] in
			guard !peopleDNString.isEmpty else {return bdn}
			let pdnc = try LDAPDistinguishedName(string: peopleDNString)
			return bdn.mapValues{ pdnc + $0 }
		}
		
		self.init(globalConfig: globalConfig, providerId: pId, serviceId: id, serviceName: name, connectorSettings: c, baseDNPerDomain: bdn, peopleBaseDNPerDomain: pdn, adminGroupsDN: adn)
	}
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, connectorSettings c: LDAPConnector.Settings, baseDNPerDomain bdn: [String: LDAPDistinguishedName], peopleBaseDNPerDomain pbdn: [String: LDAPDistinguishedName]?, adminGroupsDN agdn: [LDAPDistinguishedName]) {
		global = globalConfig
		
		precondition(id != "invalid" && id != "email" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		
		connectorSettings = c
		baseDNPerDomain = bdn
		peopleBaseDNPerDomain = pbdn
		adminGroupsDN = agdn
	}
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "Google Config"
		
		let url = try genericConfig.url(for: "url", domain: domain)
		let adminUsername = try genericConfig.optionalString(for: "admin_username", domain: domain)
		let adminPassword = try genericConfig.optionalString(for: "admin_password", domain: domain)
		
		let bdnDic    = try genericConfig.stringStringDic(for: "base_dn_per_domains", domain: domain)
		let pdnString = try genericConfig.optionalString(for: "people_dn", domain: domain)
		let adnString = try genericConfig.optionalStringArray(for: "officectl_admin_groups_dn", domain: domain) ?? []
		
		
		let connectorSettings: LDAPConnector.Settings
		switch (adminUsername, adminPassword) {
		case (.none, .none):             connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3)
		case let (username?, password?): connectorSettings = LDAPConnector.Settings(ldapURL: url, protocolVersion: .v3, username: username, password: password)
		case (.some, .none), (.none, .some):
			throw InvalidArgumentError(message: "Invalid config in yaml: neither both or none of admin_username & admin_password defined in an LDAP config")
		}
		
		try self.init(globalConfig: globalConfig, providerId: pId, serviceId: id, serviceName: name, connectorSettings: connectorSettings, baseDNPerDomainString: bdnDic, peopleDNString: pdnString, adminGroupsDNString: adnString)
	}
	
}
