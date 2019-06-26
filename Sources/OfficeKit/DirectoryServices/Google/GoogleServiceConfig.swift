/*
 * GoogleServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation



public struct GoogleServiceConfig : OfficeKitServiceConfig {
	
	public static let providerId = "internal_google"
	
	public var serviceId: String
	public var serviceName: String
	
	public var connectorSettings: GoogleJWTConnector.Settings
	public var primaryDomains: Set<String>
	
	public init(serviceId id: String, serviceName name: String, connectorSettings c: GoogleJWTConnector.Settings, primaryDomains d: Set<String>) {
		serviceId = id
		serviceName = name
		
		connectorSettings = c
		primaryDomains = d
	}
	
	public init(serviceId id: String, serviceName name: String, genericConfig: GenericConfig) throws {
		let domain = "Google Config"
		let domains        = try genericConfig.arrayOfString(for: "domains", domain: domain)
		let userBehalf     = try genericConfig.optionalString(for: "admin_email", domain: domain)
		let credsURLString = try genericConfig.string(for: "superuser_json_creds", domain: domain)
		
		let connectorSettings = GoogleJWTConnector.Settings(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf)
		self.init(serviceId: id, serviceName: name, connectorSettings: connectorSettings, primaryDomains: Set(domains))
	}
	
}
