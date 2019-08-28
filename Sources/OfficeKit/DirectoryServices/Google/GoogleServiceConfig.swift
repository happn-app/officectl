/*
 * GoogleServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import GenericStorage



public struct GoogleServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	public let isHelperService = false
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var connectorSettings: GoogleJWTConnector.Settings
	public var primaryDomains: Set<String>
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: GoogleJWTConnector.Settings, primaryDomains d: Set<String>) {
		precondition(id != "invalid" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		mergePriority = p
		
		connectorSettings = c
		primaryDomains = d
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		let domains        = try keyedConfig.arrayOfStrings(forKey: "domains",      currentKeyPath: domain)
		let userBehalf     = try keyedConfig.optionalString(forKey: "admin_email",  currentKeyPath: domain)
		let credsURLString = try keyedConfig.string(forKey: "superuser_json_creds", currentKeyPath: domain)
		
		let connectorSettings = GoogleJWTConnector.Settings(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false, relativeTo: baseURL), userBehalf: userBehalf)
		self.init(providerId: pId, serviceId: id, serviceName: name, mergePriority: p, connectorSettings: connectorSettings, primaryDomains: Set(domains))
	}
	
}
