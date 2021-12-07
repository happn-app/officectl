/*
 * HappnServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/08/2019.
 */

import Foundation

import GenericStorage



public struct HappnServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	public let isHelperService = false
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var connectorSettings: HappnConnector.Settings
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: HappnConnector.Settings) {
		precondition(id != "invalid" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		mergePriority = p
		
		connectorSettings = c
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		
		let connectorSettings = HappnConnector.Settings(
			baseURL:      try keyedConfig.url(forKey: "base_url", currentKeyPath: domain),
			clientId:     try keyedConfig.string(forKey: "client_id", currentKeyPath: domain),
			clientSecret: try keyedConfig.string(forKey: "client_secret", currentKeyPath: domain),
			username:     try keyedConfig.string(forKey: "admin_username", currentKeyPath: domain),
			password:     try keyedConfig.string(forKey: "admin_password", currentKeyPath: domain)
		)
		
		self.init(providerId: pId, serviceId: id, serviceName: name, mergePriority: p, connectorSettings: connectorSettings)
	}
	
}
