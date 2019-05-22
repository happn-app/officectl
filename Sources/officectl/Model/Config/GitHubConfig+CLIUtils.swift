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



extension OfficeKitConfig.GitHubConfig {
	
	init?(flags f: Flags, yamlConfig: Yaml) throws {
		guard let yamlGitHubConfig = yamlConfig["github"].dictionary else {return nil}
		
		guard let privateKeyURLString = yamlGitHubConfig["private_key_path"]?.string else {return nil}
		guard let appId = yamlGitHubConfig["app_id"]?.string else {return nil}
		guard let installId = yamlGitHubConfig["install_id"]?.string else {return nil}
		
		let connectorSettings = GitHubJWTConnector.Settings(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false))
		self.init(connectorSettings: connectorSettings)
	}
	
}
