/*
 * GoogleJWTConnector+CLIUtils.swift
 * officectl
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



extension GoogleJWTConnector.Settings {
	
	init?(flags f: Flags) {
		guard let credsURLString = f.getString(name: "google-superuser-json-creds") else {
			return nil
		}
		let userBehalf = f.getString(name: "google-admin-email")
		self.init(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf)
	}
	
}

extension OfficeKitConfig.GoogleConfig {
	
	init?(flags f: Flags) {
		guard let connectorSettings = GoogleJWTConnector.Settings(flags: f) else {return nil}
		
		#warning("TODO: domains")
		self.init(connectorSettings: connectorSettings, domains: [])
	}
	
}


extension GoogleJWTConnector {
	
	convenience init(flags f: Flags, userBehalf: String?) throws {
		guard let settings = GoogleJWTConnector.Settings(flags: f) else {
			throw InvalidArgumentError(message: "Cannot load Google settings from command line")
		}
		try self.init(jsonCredentialsURL: settings.jsonCredentialsURL, userBehalf: userBehalf)
	}
	
}
