/*
 * GitHubJWTConnector+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 18/07/2018.
 */

import Foundation

import Guaka

import OfficeKit



extension GitHubJWTConnector.Settings {
	
	init?(flags f: Flags) {
		guard let privateKeyURLString = f.getString(name: "github-private-key") else {return nil}
		guard let appId = f.getString(name: "github-app-id") else {return nil}
		guard let installId = f.getString(name: "github-install-id") else {return nil}
		
		self.init(appId: appId, installationId: installId, privateKeyURL: URL(fileURLWithPath: privateKeyURLString, isDirectory: false))
	}
	
}

extension OfficeKitConfig.GitHubConfig {
	
	init?(flags f: Flags) {
		guard let connectorSettings = GitHubJWTConnector.Settings(flags: f) else {return nil}
		
		self.init(connectorSettings: connectorSettings)
	}
	
}


extension GitHubJWTConnector {
	
	public convenience init(flags f: Flags) throws {
		guard let settings = GitHubJWTConnector.Settings(flags: f) else {
			throw InvalidArgumentError(message: "Cannot load GitHub settings from command line")
		}
		try self.init(key: settings)
	}
	
}
