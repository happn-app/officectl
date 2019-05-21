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
	
	init?(flags f: Flags, yamlConfig: Yaml?) throws {
		let yamlGitHubConfig = yamlConfig?["github"]
		
		guard let privateKeyURLString = f.getString(name: "github-private-key-path") ?? yamlGitHubConfig?["private_key_path"].string else {return nil}
		guard let appId = f.getString(name: "github-app-id") ?? yamlGitHubConfig?["app_id"].string else {return nil}
		guard let installId = f.getString(name: "github-install-id") ?? yamlGitHubConfig?["install_id"].string else {return nil}
		
		let connectorSettings = GitHubJWTConnector.Settings(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false))
		self.init(connectorSettings: connectorSettings)
	}
	
}
