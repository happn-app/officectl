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
	
	init?(flags f: Flags, yamlConfig: Yaml?) throws {
		guard let credsURLString = f.getString(name: "google-superuser-json-creds") else {
			return nil
		}
		let userBehalf = f.getString(name: "google-admin-email")
		let connectorSettings = GoogleJWTConnector.Settings(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf)
		
		#warning("TODO: domains")
		self.init(connectorSettings: connectorSettings, domains: [])
	}
	
}
