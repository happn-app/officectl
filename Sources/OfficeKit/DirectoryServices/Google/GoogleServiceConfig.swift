/*
 * GoogleServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation



public struct GoogleServiceConfig {
	
	public var connectorSettings: GoogleJWTConnector.Settings
	public var primaryDomains: Set<String>
	
	public init(connectorSettings c: GoogleJWTConnector.Settings, primaryDomains d: Set<String>) {
		connectorSettings = c
		primaryDomains = d
	}
	
//	public init(dictionary: [String : Any?]) throws {
//		let domain = "GoogleConfig"
//		let credsURLString: String = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "superuser_json_creds", domain: domain)
//		let domains: [String]      = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "domains",              domain: domain)
//		let userBehalf: String?    = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "admin_email",          domain: domain)
//		
//		let connectorSettings = GoogleJWTConnector.Settings(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf)
//		self.init(connectorSettings: connectorSettings, primaryDomains: Set(domains))
//	}
	
}
