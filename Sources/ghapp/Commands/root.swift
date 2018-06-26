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


private func inheritablePreRun(flags: Flags, args: [String]) -> Bool {
	let jsonCredsURL = URL(fileURLWithPath: flags.getString(name: "superuser-json-creds")!, isDirectory: false)
	guard let googleConnector = GoogleJWTConnector(jsonCredentialsURL: jsonCredsURL) else {
		rootCommand.fail(statusCode: 1, errorMessage: "Cannot read superuser creds")
	}
	
	/* The whole guard below can be removed once we get rid of Superuser */
	var keys: CFArray?
	guard
		let superuserCreds = (try? JSONSerialization.jsonObject(with: Data(contentsOf: jsonCredsURL), options: [])) as? [String: String],
		let jsonCredsType = superuserCreds["type"], jsonCredsType == "service_account",
		let superuserPEMKey = superuserCreds["private_key"]?.data(using: .utf8), let superuserEmail = superuserCreds["client_email"],
		SecItemImport(superuserPEMKey as CFData, nil, nil, nil, [], nil, nil, &keys) == 0, let superuserKey = (keys as? [SecKey])?.first
	else {
		rootCommand.fail(statusCode: 1, errorMessage: "Cannot read superuser creds")
	}
	
	rootConfig = RootConfig(adminEmail: flags.getString(name: "admin-email")!, googleConnector: googleConnector, superuser: Superuser(email: superuserEmail, privateKey: superuserKey))
	return true
}

private func execute(command: Command, flags: Flags, args: [String]) {
	rootCommand.fail(statusCode: 1, errorMessage: "Please choose a command verb")
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
