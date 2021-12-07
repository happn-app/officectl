/*
 * GitHubServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import GenericStorage



public struct GitHubServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	public let isHelperService = false
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var connectorSettings: GitHubJWTConnector.Settings
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: GitHubJWTConnector.Settings) {
		precondition(id != "invalid" && !id.contains(":"))
		providerId = pId
		serviceId = id
		serviceName = name
		mergePriority = p
		
		connectorSettings = c
	}
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		let appId               = try keyedConfig.string(forKey: "app_id",             currentKeyPath: domain)
		let installId           = try keyedConfig.string(forKey: "install_id",         currentKeyPath: domain)
		let privateKeyURLString = try keyedConfig.string(forKey: "private_key_path",   currentKeyPath: domain)
		
		let connectorSettings = GitHubJWTConnector.Settings(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false, relativeTo: baseURL))
		self.init(providerId: pId, serviceId: id, serviceName: name, mergePriority: p, connectorSettings: connectorSettings)
	}
	
}
