/*
 * get-token.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka

import OfficeKit



class GetTokenOperation : CommandOperation {
	
	let googleConnectorOperation: GetConnectedGoogleConnector
	
	override init(command c: Command, flags f: Flags, arguments args: [String]) {
		do {
			let scopes = f.getString(name: "scopes")!
			let userBehalf = f.getString(name: "google-admin-email")!
			googleConnectorOperation = try GetConnectedGoogleConnector(flags: f, scope: Set(scopes.components(separatedBy: ",")), userBehalf: userBehalf)
		} catch {
			c.fail(statusCode: (error as NSError).code, errorMessage: error.localizedDescription)
		}
		
		super.init(command: c, flags: f, arguments: args)
		
		addDependency(googleConnectorOperation)
	}
	
	override func startBaseOperation(isRetry: Bool) {
		if let e = googleConnectorOperation.connectionError as NSError? {
			command.fail(statusCode: e.code, errorMessage: e.localizedDescription)
		}
		
		print(googleConnectorOperation.connector.token!)
		baseOperationEnded()
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}
