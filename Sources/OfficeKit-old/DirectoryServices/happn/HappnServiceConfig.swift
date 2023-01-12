/*
 * HappnServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/28.
 */

import Foundation

import GenericStorage



public struct HappnServiceConfig : OfficeKitServiceConfig, Sendable {
	
	public var providerID: String
	public let isHelperService = false
	
	public var serviceID: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var connectorSettings: HappnConnector.Settings
	
	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: HappnConnector.Settings) {
		precondition(id != "invalid" && !id.contains(":"))
		providerID = pID
		serviceID = id
		serviceName = name
		mergePriority = p
		
		connectorSettings = c
	}
	
	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		
		let connectorSettings = HappnConnector.Settings(
			baseURL:      try keyedConfig.url(forKey: "base_url", currentKeyPath: domain),
			clientID:     try keyedConfig.string(forKey: "client_id", currentKeyPath: domain),
			clientSecret: try keyedConfig.string(forKey: "client_secret", currentKeyPath: domain),
			username:     try keyedConfig.string(forKey: "admin_username", currentKeyPath: domain),
			password:     try keyedConfig.string(forKey: "admin_password", currentKeyPath: domain)
		)
		
		self.init(providerID: pID, serviceID: id, serviceName: name, mergePriority: p, connectorSettings: connectorSettings)
	}
	
}
