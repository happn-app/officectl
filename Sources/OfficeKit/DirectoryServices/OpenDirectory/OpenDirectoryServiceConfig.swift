/*
 * OpenDirectoryServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/20.
 */

#if !canImport(DirectoryService) || !canImport(OpenDirectory)

public typealias OpenDirectoryServiceConfig = LDAPServiceConfig

#else

import Foundation
import OpenDirectory

import GenericStorage



public struct OpenDirectoryServiceConfig : OfficeKitServiceConfig {
	
	public var providerID: String
	public let isHelperService = false
	
	public var serviceID: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var connectorSettings: OpenDirectoryConnector.Settings
	public var baseDNs: LDAPBaseDNs
	
	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: OpenDirectoryConnector.Settings, baseDNPerDomainString: [String: String], peopleDNString: String?) throws {
		precondition(id != "invalid" && !id.contains(":"))
		providerID = pID
		serviceID = id
		serviceName = name
		mergePriority = p
		
		connectorSettings = c
		baseDNs = try LDAPBaseDNs(baseDNPerDomainString: baseDNPerDomainString, peopleDNString: peopleDNString)
	}
	
	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		
		let proxySettings = try keyedConfig.optionalNonNullStorage(forKey: "proxy", currentKeyPath: domain).flatMap{ proxyKeyedConfig -> OpenDirectoryConnector.ProxySettings in
			let keyPath = domain + ["proxy"]
			return (
				hostname: try proxyKeyedConfig.string(forKey: "hostname", currentKeyPath: keyPath),
				username: try proxyKeyedConfig.string(forKey: "username", currentKeyPath: keyPath),
				password: try proxyKeyedConfig.string(forKey: "password", currentKeyPath: keyPath)
			)
		}
		
		let nodeName = try keyedConfig.string(forKey: "node_name", currentKeyPath: domain)
		let username = try keyedConfig.string(forKey: "admin_username", currentKeyPath: domain)
		let password = try keyedConfig.string(forKey: "admin_password", currentKeyPath: domain)
		
		let bdnDic    = try keyedConfig.dictionaryOfStrings(forKey: "base_dn_per_domains", currentKeyPath: domain)
		let pdnString = try keyedConfig.optionalString(forKey: "people_dn", currentKeyPath: domain)
		
		let connectorSettings = OpenDirectoryConnector.Settings(proxySettings: proxySettings, nodeName: nodeName, nodeCredentials: (recordType: kODRecordTypeUsers, username: username, password: password))
		try self.init(providerID: pID, serviceID: id, serviceName: name, mergePriority: p, connectorSettings: connectorSettings, baseDNPerDomainString: bdnDic, peopleDNString: pdnString)
	}
	
}

#endif
