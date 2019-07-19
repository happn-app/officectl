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
	public var baseDNPerDomain: [String: LDAPDistinguishedName]
	public var peopleBaseDNPerDomain: [String: LDAPDistinguishedName]?
	
	public var allBaseDNs: Set<LDAPDistinguishedName> {
		return Set(baseDNPerDomain.values)
	}
	
	public var allDomains: Set<String> {
		return Set(baseDNPerDomain.keys)
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, connectorSettings c: OpenDirectoryConnector.Settings, baseDNPerDomainString: [String: String], peopleDNString: String?) throws {
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
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "OpenDirectory Config"
		
		let proxySettings = try genericConfig.optionalGenericConfig(for: "proxy", domain: domain).flatMap{ proxyGenericConfig -> OpenDirectoryConnector.ProxySettings in
			let domain = "OpenDirectory Proxy Config"
			return (
				hostname: try proxyGenericConfig.string(for: "hostname", domain: domain),
				username: try proxyGenericConfig.string(for: "username", domain: domain),
				password: try proxyGenericConfig.string(for: "password", domain: domain)
			)
		}
		
		let nodeName = try genericConfig.string(for: "node_name", domain: domain)
		let username = try genericConfig.string(for: "username", domain: domain)
		let password = try genericConfig.string(for: "password", domain: domain)
		
		let bdnDic    = try genericConfig.stringStringDic(for: "base_dn_per_domains", domain: domain)
		let pdnString = try genericConfig.optionalString(for: "people_dn", domain: domain)
		
		let connectorSettings = OpenDirectoryConnector.Settings(proxySettings: proxySettings, nodeName: nodeName, nodeCredentials: (recordType: kODRecordTypeUsers, username: username, password: password))
		try self.init(providerId: pId, serviceId: id, serviceName: name, connectorSettings: connectorSettings, baseDNPerDomainString: bdnDic, peopleDNString: pdnString)
	}
	
}

#endif
