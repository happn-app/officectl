/*
 * GoogleConfig+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import Guaka
import Yaml

import OfficeKit



extension GoogleServiceConfig {
	
	init(flags f: Flags, yamlConfig: Yaml) throws {
		let credsURLString = try yamlConfig.string(for: "superuser_json_creds")
		let domains        = try yamlConfig.arrayOfString(for: "domains")
		let userBehalf     = try yamlConfig.optionalString(for: "admin_email")
		
		let connectorSettings = GoogleJWTConnector.Settings(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf)
		self.init(connectorSettings: connectorSettings, primaryDomains: Set(domains))
	}
	
}
