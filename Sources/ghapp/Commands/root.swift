/*
 * root.swift
 * ghapp
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation
import Security

import Guaka
import RetryingOperation



class RootOperation : CommandOperation {
	
	override func startBaseOperation(isRetry: Bool) {
		command.fail(statusCode: 1, errorMessage: "Please choose a command verb")
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}


class GetConnectedGoogleConnector : CommandOperation {
	
	let scope: GoogleJWTConnectorScope
	
	let connector: GoogleJWTConnector
	
	init(command cmd: Command, flags f: Flags, arguments args: [String], scope s: GoogleJWTConnectorScope) {
		let credsURL = URL(fileURLWithPath: f.getString(name: "superuser-json-creds")!, isDirectory: false)
		guard let c = GoogleJWTConnector(jsonCredentialsURL: credsURL) else {
			cmd.fail(statusCode: 1, errorMessage: "Cannot create the Google connector (does the credentials file exist?)")
		}
		
		scope = s
		connector = c
		
		super.init(command: cmd, flags: f, arguments: args)
	}
	
	override func startBaseOperation(isRetry: Bool) {
		connector.connect(scope: scope, handler: { error in
			guard self.connector.isConnected else {self.command.fail(statusCode: 1, errorMessage: error?.localizedDescription ?? "Unknown Google connection error")}
			self.baseOperationEnded()
		})
	}
	
}



/* ***** Config Object ***** */

@available(*, deprecated)
var rootConfig: RootConfig!

struct RootConfig {
	
	let adminEmail: String
	let googleConnector: GoogleJWTConnector
	
	@available(*, deprecated)
	let superuser: Superuser
	
}
