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
		guard let privateKeyURLString = f.getString(name: "github-private-key-path") else {return nil}
		guard let appId = f.getString(name: "github-app-id") else {return nil}
		guard let installId = f.getString(name: "github-install-id") else {return nil}
		
		let connectorSettings = GitHubJWTConnector.Settings(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false))
		self.init(connectorSettings: connectorSettings)
	}
	
}
