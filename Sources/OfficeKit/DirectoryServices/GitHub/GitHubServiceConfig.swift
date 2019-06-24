/*
 * GitHubServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation


public struct GitHubServiceConfig {
	
	public var connectorSettings: GitHubJWTConnector.Settings
	
	public init(connectorSettings c: GitHubJWTConnector.Settings) {
		connectorSettings = c
	}
	
//	public init(dictionary: [String : Any?]) throws {
//		let domain = "GitHubConfig"
//		let privateKeyURLString: String = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "private_key_path", domain: domain)
//		let appId: String               = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "app_id",           domain: domain)
//		let installId: String           = try OpenDirectoryServiceConfig.getConfigValue(from: dictionary, key: "install_id",       domain: domain)
//		
//		let connectorSettings = GitHubJWTConnector.Settings(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false))
//		self.init(connectorSettings: connectorSettings)
//	}
	
}
