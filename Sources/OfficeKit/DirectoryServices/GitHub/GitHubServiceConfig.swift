/*
 * GitHubServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import GenericStorage



public struct GitHubServiceConfig : OfficeKitServiceConfig {
	
	public var global: GlobalConfig
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var connectorSettings: GitHubJWTConnector.Settings
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, connectorSettings c: GitHubJWTConnector.Settings) {
		global = globalConfig
		
		precondition(id != "invalid" && id != "email" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		
		connectorSettings = c
	}
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		let appId               = try genericConfig.string(forKey: "app_id",           currentKeyPath: domain)
		let installId           = try genericConfig.string(forKey: "install_id",       currentKeyPath: domain)
		let privateKeyURLString = try genericConfig.string(forKey: "private_key_path", currentKeyPath: domain)
		
		let connectorSettings = GitHubJWTConnector.Settings(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false, relativeTo: baseURL))
		self.init(globalConfig: globalConfig, providerId: pId, serviceId: id, serviceName: name, connectorSettings: connectorSettings)
	}
	
}
