/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation

import NIO

import OfficeKit



func curTest(flags f: Flags, arguments args: [String], asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
	guard let c = LDAPConnector(ldapURL: URL(string: "ldap://vip-ldap.happn.io")!, protocolVersion: .v3/*, username: "cn=admin,dc=happn,dc=com", password: "REDACTED"*/) else {
		return asyncConfig.eventLoop.newFailedFuture(error: NSError(domain: "lol", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot instantiate the LDAP Connector"]))
	}
	
	let f = c.connect(scope: (), asyncConfig: asyncConfig)
	.then{ _ -> EventLoopFuture<[LDAPObject]> in
		let searchOp = LDAPSearchOperation(ldapConnector: c, request: LDAPRequest(scope: .children, base: "dc=happn,dc=com", searchFilter: nil, attributesToFetch: nil))
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.defaultOperationQueue, resultRetriever: { (searchOp) -> [LDAPObject] in try searchOp.results.successValueOrThrow().results })
	}
	.then{ ldapObjects -> EventLoopFuture<Void> in
		print(ldapObjects.compactMap{ $0.inetOrgPerson })
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
	return f
}
