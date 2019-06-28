/*
 * list-users.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func listUsers(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	#if false
	let asyncConfig: AsyncConfig = try context.container.make()
	let googleConfig = try context.container.make(OfficeKitConfig.self).googleConfigOrThrow()
	
	_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
	
	let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
	let f = googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
	.then{ _ -> Future<[GoogleUser]> in
		let searchOp = SearchGoogleUsersOperation(searchedDomain: "happn.fr", googleConnector: googleConnector)
		return context.container.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: { try $0.result.get() })
	}
	.then{ users -> Future<Void> in
		var i = 1
		for user in users {
			print(user.primaryEmail.stringValue + ",", terminator: "")
			if i == 69 {print(); print(); i = 0}
			i += 1
		}
		print()
		return context.container.eventLoop.newSucceededFuture(result: ())
	}
	return f
	#endif
	throw NotImplementedError()
}
