/*
 * GetConnectedGoogleConnector.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation

import Guaka



class GetConnectedGoogleConnector : CommandOperation {
	
	let scope: Set<String>
	
	let connector: GoogleJWTConnector
	
	init(command cmd: Command, flags f: Flags, arguments args: [String], scope s: Set<String>, userBehalf: String?) {
		guard let credsURLString = f.getString(name: "google-superuser-json-creds") else {
			cmd.fail(statusCode: 1, errorMessage: "The google-superuser-json-creds argument is required for commands dealing with Google APIs")
		}
		guard let c = GoogleJWTConnector(jsonCredentialsURL: URL(fileURLWithPath: credsURLString, isDirectory: false), userBehalf: userBehalf) else {
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
