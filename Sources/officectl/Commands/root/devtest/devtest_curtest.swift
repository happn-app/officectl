/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func curTest(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let asyncConfig: AsyncConfig = try context.container.make()
	
	let c = try LDAPConnector(flags: f)
	let f = c.connect(scope: (), asyncConfig: asyncConfig)
	.then{ _ -> EventLoopFuture<[LDAPObject]> in
		let searchOp = LDAPSearchOperation(ldapConnector: c, request: LDAPRequest(scope: .children, base: "dc=happn,dc=com", searchQuery: nil, attributesToFetch: nil))
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: { try $0.results.successValueOrThrow().results })
	}
	.then{ ldapObjects -> EventLoopFuture<Void> in
		print(ldapObjects.compactMap{ $0.inetOrgPerson })
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
	return f
}
