/*
 * GoogleServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation



public struct GoogleServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var connectorSettings: GoogleJWTConnector.Settings
	public var primaryDomains: Set<String>
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, connectorSettings c: GoogleJWTConnector.Settings, primaryDomains d: Set<String>) {
		precondition(id != "email" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		
		connectorSettings = c
		primaryDomains = d
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericConfig, pathsRelativeTo baseURL: URL?) throws {
		let domain = "Google Config"
		let domains        = try genericConfig.stringArray(for: "domains", domain: domain)
		let userBehalf     = try genericConfig.optionalString(for: "admin_email", domain: domain)
		let credsURLString = try genericConfig.string(for: "superuser_json_creds", domain: domain)
		
		let connectorSettings = GoogleJWTConnector.Settings(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false, relativeTo: baseURL), userBehalf: userBehalf)
		self.init(providerId: pId, serviceId: id, serviceName: name, connectorSettings: connectorSettings, primaryDomains: Set(domains))
	}
	
}
