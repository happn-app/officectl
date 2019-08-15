/*
 * GoogleServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import GenericStorage



public struct GoogleServiceConfig : OfficeKitServiceConfig {
	
	public var global: GlobalConfig
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var connectorSettings: GoogleJWTConnector.Settings
	public var primaryDomains: Set<String>
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: GoogleJWTConnector.Settings, primaryDomains d: Set<String>) {
		global = globalConfig
		
		precondition(id != "invalid" && id != "email" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		mergePriority = p
		
		connectorSettings = c
		primaryDomains = d
	}
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		let domains        = try genericConfig.arrayOfStrings(forKey: "domains",      currentKeyPath: domain)
		let userBehalf     = try genericConfig.optionalString(forKey: "admin_email",  currentKeyPath: domain)
		let credsURLString = try genericConfig.string(forKey: "superuser_json_creds", currentKeyPath: domain)
		let mp             = try genericConfig.optionalInt(forKey: "mergePriority",   currentKeyPath: domain)
		
		let connectorSettings = GoogleJWTConnector.Settings(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false, relativeTo: baseURL), userBehalf: userBehalf)
		self.init(globalConfig: globalConfig, providerId: pId, serviceId: id, serviceName: name, mergePriority: mp, connectorSettings: connectorSettings, primaryDomains: Set(domains))
	}
	
}
