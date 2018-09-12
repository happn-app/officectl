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
	.then{ _ -> EventLoopFuture<Void> in
		let user = LDAPInetOrgPerson(dn: "uid=ldap.test,ou=people,dc=happn,dc=com", sn: ["Test"], cn: ["Ldap Test"])
		user.userPassword = "hello!"
		let op = ModifyLDAPPasswordsOperation(users: [user], connector: c)
		return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue, resultRetriever: { if let e = $0.errors.first! {throw e} })
	}
	.then{ _ -> EventLoopFuture<Void> in
		let searchOp = SearchLDAPOperation(ldapConnector: c, request: LDAPRequest(scope: .children, base: "dc=happn,dc=com", searchQuery: LDAPSearchQuery.simple(attribute: LDAPAttributeDescription(string: "uid")!, filtertype: .equal, value: Data("ldap.test".utf8)), attributesToFetch: ["userPassword", "cn", "sn"]))
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: { print(try $0.results.successValueOrThrow().results.first?.stringValues(for: "userPassword") ?? "<No Results>"); return })
	}
	return f
}
