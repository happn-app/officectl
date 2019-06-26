/*
 * GitHubServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation



public struct GitHubServiceConfig : OfficeKitServiceConfig {
	
	public static let providerId = "internal_github"
	
	public var serviceId: String
	public var serviceName: String
	
	public var connectorSettings: GitHubJWTConnector.Settings
	
	public init(serviceId id: String, serviceName name: String, connectorSettings c: GitHubJWTConnector.Settings) {
		serviceId = id
		serviceName = name
		
		connectorSettings = c
	}
	
	public init(serviceId id: String, serviceName name: String, genericConfig: GenericConfig) throws {
		let domain = "GitHub Config"
		let appId               = try genericConfig.string(for: "app_id",           domain: domain)
		let installId           = try genericConfig.string(for: "install_id",       domain: domain)
		let privateKeyURLString = try genericConfig.string(for: "private_key_path", domain: domain)
		
		let connectorSettings = GitHubJWTConnector.Settings(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false))
		self.init(serviceId: id, serviceName: name, connectorSettings: connectorSettings)
	}
	
}
