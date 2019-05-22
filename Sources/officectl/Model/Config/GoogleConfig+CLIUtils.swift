/*
 * GoogleConfig+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import Guaka
import Vapor
import Yaml

import OfficeKit



extension OfficeKitConfig.GoogleConfig {
	
	init?(flags f: Flags, yamlConfig: Yaml) throws {
		guard let yamlGoogleConfig = yamlConfig["google"].dictionary else {return nil}
		
		guard let credsURLString = yamlGoogleConfig["superuser_json_creds"]?.string else {
			return nil
		}
		guard let domains = try yamlGoogleConfig["domains"]?.arrayOfStringOrThrow() else {
			return nil
		}
		let userBehalf = yamlGoogleConfig["admin_email"]?.string
		let connectorSettings = GoogleJWTConnector.Settings(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf)
		
		self.init(connectorSettings: connectorSettings, primaryDomains: Set(domains))
	}
	
}
