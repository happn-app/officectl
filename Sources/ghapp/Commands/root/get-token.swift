/*
 * get-token.swift
 * ghapp
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

//private func execute(command: Command, flags: Flags, args: [String]) {
//	let op = HandlerOperation{ endOperation in
//		rootConfig.googleConnector.connect(scope: GoogleJWTConnector.ScopeType(userBehalf: rootConfig.adminEmail, scope: Set(flags.getString(name: "scopes")!.components(separatedBy: ","))), handler: { error in
//			print(rootConfig.googleConnector.token ?? "Cannot retrieve Gogol token")
//
//			let gitHubConnector = GitHubJWTConnector(appId: "14017", installationId: "220844", privateKeyURL: URL(fileURLWithPath: "/Users/frizlab/Downloads/officectl.2018-06-25.private-key.pem", isDirectory: false))!
//			gitHubConnector.connect(scope: (), handler: { error in
//				print(gitHubConnector.token ?? "Cannot retrieve GitHub token")
//				endOperation()
//			})
//		})
//	}
//	op.start()
//	repeat {
//		RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 0.1))
//	} while !op.isFinished
//}
