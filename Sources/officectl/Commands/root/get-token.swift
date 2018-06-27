/*
 * get-token.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation



class GetTokenOperation : CommandOperation {
	
	let googleConnectorOperation: GetConnectedGoogleConnector
	
	override init(command c: Command, flags f: Flags, arguments args: [String]) {
		let scopes = f.getString(name: "scopes")!
		let scope = GoogleJWTConnector.ScopeType(userBehalf: f.getString(name: "admin-email")!, scope: Set(scopes.components(separatedBy: ",")))
		googleConnectorOperation = GetConnectedGoogleConnector(command: c, flags: f, arguments: args, scope: scope)
		
		super.init(command: c, flags: f, arguments: args)
		
		addDependency(googleConnectorOperation)
	}
	
	override func startBaseOperation(isRetry: Bool) {
		print(googleConnectorOperation.connector.token!)
		baseOperationEnded()
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}
