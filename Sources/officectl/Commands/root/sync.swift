/*
 * sync.swift
 * officectl
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation

import AsyncOperationResult
import Guaka
import Vapor

import OfficeKit



private enum Service : String {
	
	case ldap
	case google
	case github
	
}

struct Connectors {
	
	var ldapConnector: LDAPConnector!
	var googleConnector: GoogleJWTConnector!
	
	init() {
	}
	
}

func sync(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let asyncConfig: AsyncConfig = try context.container.make()
	
	var connectors = Connectors()
	var service2FutureUsers = [Service: EventLoopFuture<(Service, [HappnUser])>]()
	
	
	/* *** Parse command line options *** */
	let fromStr = f.getString(name: "from")!
	guard let fromService = Service(rawValue: fromStr) else {
		throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid \"from\" value for syncing directories: \(fromStr)"])
	}
	let toServices = try f.getString(name: "to")!.split(separator: ",").map{ substr -> Service in
		let strService = String(substr)
		guard let s = Service(rawValue: strService) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid \"to\" value for syncing directories: \(strService)"])
		}
		return s
	}
	
	/* *** Connect services connectors and retrieve all (future) users from required services *** */
	for s in [fromService] + toServices {
		guard service2FutureUsers[s] == nil else {continue}
		switch s {
		case .google:
			let userBehalf = f.getString(name: "google-admin-email")!
			connectors.googleConnector = try GoogleJWTConnector(flags: f, userBehalf: userBehalf)
			service2FutureUsers[s] =
				connectors.googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
				.then{ happnUsersFromGoogle(connector: connectors.googleConnector, asyncConfig: asyncConfig) }
			
		case .ldap:
			connectors.ldapConnector = try LDAPConnector(flags: f)
			service2FutureUsers[s] =
				connectors.ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
				.then{ happnUsersFromLDAP(connector: connectors.ldapConnector, asyncConfig: asyncConfig) }
			
		case .github: throw NSError(domain: "com.happn.officectl", code: 255, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
		}
	}
	
	/* *** Launch sync *** */
	let f = EventLoopFuture.reduce(into: [Service: [HappnUser]](), Array(service2FutureUsers.values), eventLoop: asyncConfig.eventLoop, { currentValue, newValue in
		let (service, users) = newValue
		currentValue[service] = users
	})
	.then{ syncFromGoogleToLDAP(users: $0, connectors: connectors, asyncConfig: asyncConfig) }
	return f
}

private func syncFromGoogleToLDAP(users: [Service: [HappnUser]], connectors: Connectors, asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
	#warning("temp code")
	let ldapUsers = Set(users[.ldap]!)
	let googleUsers = Set(users[.google]!)
	let usersToCreate = googleUsers.subtracting(ldapUsers)
	
	let ldapUsersToCreate = usersToCreate.compactMap{ $0.ldapInetOrgPerson(baseDN: "dc=happn,dc=com") }
	let createUsersOperation = CreateLDAPObjectsOperation(users: Array(ldapUsersToCreate), connector: connectors.ldapConnector)
	return asyncConfig.eventLoop.future(from: createUsersOperation, queue: asyncConfig.operationQueue, resultRetriever: { _ in return () })
}

private func happnUsersFromGoogle(connector: GoogleJWTConnector, asyncConfig: AsyncConfig) -> EventLoopFuture<(Service, [HappnUser])> {
	let searchOp = SearchGoogleUsersOperation(searchedDomain: "happn.fr", googleConnector: connector)
	return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: {
		(.google, try $0.result.successValueOrThrow().map{ HappnUser(googleUser: $0) })
	})
}

private func happnUsersFromLDAP(connector: LDAPConnector, asyncConfig: AsyncConfig) -> EventLoopFuture<(Service, [HappnUser])> {
	let searchOp = SearchLDAPOperation(ldapConnector: connector, request: LDAPSearchRequest(scope: .children, base: "dc=happn,dc=com", searchQuery: nil, attributesToFetch: nil))
	return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: {
		(.ldap, try $0.results.successValueOrThrow().results.compactMap{ $0.inetOrgPerson }.compactMap{ HappnUser(ldapInetOrgPerson: $0) })
	})
}
