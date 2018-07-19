/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import NIO

import OfficeKit



func curTest(flags f: Flags, arguments args: [String], asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
	guard let c = try? LDAPConnector(flags: f) else {
		return asyncConfig.eventLoop.newFailedFuture(error: NSError(domain: "lol", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot instantiate the LDAP Connector"]))
	}
	
	let f = c.connect(scope: (), asyncConfig: asyncConfig)
	.then{ _ -> EventLoopFuture<[LDAPObject]> in
		let searchOp = LDAPSearchOperation(ldapConnector: c, request: LDAPRequest(scope: .children, base: "dc=happn,dc=com", searchFilter: nil, attributesToFetch: nil))
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.defaultOperationQueue, resultRetriever: { try $0.results.successValueOrThrow().results })
	}
	.then{ ldapObjects -> EventLoopFuture<Void> in
		print(ldapObjects.compactMap{ $0.inetOrgPerson })
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
	return f
}
