/*
 * GitHubServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/20.
 */

import Foundation

import GenericStorage



public struct GitHubServiceConfig : OfficeKitServiceConfig {
	
	public var providerID: String
	public let isHelperService = false
	
	public var serviceID: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public var connectorSettings: GitHubJWTConnector.Settings
	
	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, connectorSettings c: GitHubJWTConnector.Settings) {
		precondition(id != "invalid" && !id.contains(":"))
		providerID = pID
		serviceID = id
		serviceName = name
		mergePriority = p
		
		connectorSettings = c
	}
	
	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		let domain = [id]
		let appID               = try keyedConfig.string(forKey: "app_id",             currentKeyPath: domain)
		let installID           = try keyedConfig.string(forKey: "install_id",         currentKeyPath: domain)
		let privateKeyURLString = try keyedConfig.string(forKey: "private_key_path",   currentKeyPath: domain)
		
		let connectorSettings = GitHubJWTConnector.Settings(appID: appID, installationID: installID, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false, relativeTo: baseURL))
		self.init(providerID: pID, serviceID: id, serviceName: name, mergePriority: p, connectorSettings: connectorSettings)
	}
	
}
