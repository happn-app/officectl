/*
 * GitHubConfig+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 18/07/2018.
 */

import Foundation

import Guaka
import Yaml

import OfficeKit



extension GitHubServiceConfig {
	
	init(flags f: Flags, yamlConfig: Yaml) throws {
		let privateKeyURLString = try yamlConfig.string(for: "private_key_path")
		let appId               = try yamlConfig.string(for: "app_id")
		let installId           = try yamlConfig.string(for: "install_id")
		
		let connectorSettings = GitHubJWTConnector.Settings(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false))
		self.init(connectorSettings: connectorSettings)
	}
	
}
