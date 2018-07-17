/*
 * list-users.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import NIO

import OfficeKit



func listUsers(flags f: Flags, arguments args: [String], asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
	do {
		let userBehalf = f.getString(name: "google-admin-email")!
		let scope = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly")
		let googleConnector = try GoogleJWTConnector(flags: f, userBehalf: userBehalf)
		
		let f = googleConnector.connect(scope: scope, asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[GoogleUser]> in
			let searchOp = GoogleUserSearchOperation(searchedDomain: "happn.fr", googleConnector: googleConnector)
			return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.defaultOperationQueue, resultRetriever: { (searchOp) -> [GoogleUser] in try searchOp.result.successValueOrThrow() })
		}
		.then{ users -> EventLoopFuture<Void> in
			var i = 1
			for user in users {
				print(user.primaryEmail.stringValue + ",", terminator: "")
				if i == 69 {print(); print(); i = 0}
				i += 1
			}
			print()
			return asyncConfig.eventLoop.newSucceededFuture(result: ())
		}
		return f
	} catch {
		return asyncConfig.eventLoop.newFailedFuture(error: error)
	}
}
