/*
 * sync.swift
 * officectl
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



struct Connectors {
	
	var ldapConnector: LDAPConnector!
	var googleConnector: GoogleJWTConnector!
	
	init() {
	}
	
}

func sync(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	#warning("TODO: Manage multiple domains")
	#if false
	let asyncConfig = try context.container.make(AsyncConfig.self)
	let officeKitConfig = try context.container.make(OfficeKitConfig.self)
	
	var connectors = Connectors()
	var sourceId2FutureUsers = [SourceId: Future<(SourceId, [User])>]()
	
	
	/* *** Parse command line options *** */
	let googleDomain: String!
	let fromStr = f.getString(name: "from")!
	let ldapBasePeopleDN: LDAPDistinguishedName!
	guard let fromSourceId = SourceId(rawValue: fromStr) else {
		throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid \"from\" value for syncing directories: \(fromStr)"])
	}
	let toSourceIds = try f.getString(name: "to")!.split(separator: ",").map{ substr -> SourceId in
		let strSourceId = String(substr)
		guard let s = SourceId(rawValue: strSourceId) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid \"to\" value for syncing directories: \(strSourceId)"])
		}
		return s
	}
	if fromSourceId == .ldap || toSourceIds.contains(.ldap) {
		let baseDNs = try nil2throw(officeKitConfig.ldapConfigOrThrow().peopleBaseDNPerDomain?.values, "People DN")
		guard baseDNs.count == 1 else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Only one LDAP domain supported for now"])
		}
		ldapBasePeopleDN = baseDNs.first!
	} else {
		ldapBasePeopleDN = nil
	}
	if fromSourceId == .google || toSourceIds.contains(.google) {
		let domains = try nil2throw(officeKitConfig.googleConfigOrThrow().primaryDomains, "Google Domains")
		guard domains.count == 1 else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Only one Google domain supported for now"])
		}
		googleDomain = domains.first!
	} else {
		googleDomain = nil
	}
	
	/* *** Connect sources connectors and retrieve all (future) users from required sources *** */
	for s in [fromSourceId] + toSourceIds {
		guard sourceId2FutureUsers[s] == nil else {continue}
		switch s {
		case .google:
			let googleConfig = try officeKitConfig.googleConfigOrThrow()
			_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
			connectors.googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
			sourceId2FutureUsers[s] =
				connectors.googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
				.then{ usersFromGoogle(connector: connectors.googleConnector, searchedDomain: googleDomain, baseDN: ldapBasePeopleDN, asyncConfig: asyncConfig) }
			
		case .ldap:
			connectors.ldapConnector = try LDAPConnector(key: officeKitConfig.ldapConfigOrThrow().connectorSettings)
			sourceId2FutureUsers[s] =
				connectors.ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
				.then{ usersFromLDAP(connector: connectors.ldapConnector, baseDN: ldapBasePeopleDN, asyncConfig: asyncConfig) }
			
		case .github:
			throw NotImplementedError()
		}
	}
	
	/* *** Launch sync *** */
	let f = Future.reduce(into: [SourceId: [User]](), Array(sourceId2FutureUsers.values), eventLoop: asyncConfig.eventLoop, { currentValue, newValue in
		let (sourceId, users) = newValue
		currentValue[sourceId] = users
	})
	.then{ usersBySourceId -> Future<Void> in
		switch fromSourceId {
		case .google: return syncFromGoogle(to: toSourceIds, users: usersBySourceId, baseDN: ldapBasePeopleDN, connectors: connectors, asyncConfig: asyncConfig, console: context.console)
		case .ldap:   return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
		case .github: return asyncConfig.eventLoop.newFailedFuture(error: BasicValidationError("Cannot sync from GitHub (GitHub’s directory does not have enough information)"))
		}
	}
	return f
	#endif
	throw NotImplementedError()
}

#if false
private func syncFromGoogle(to toSourceIds: [SourceId], users: [SourceId: [User]], baseDN: LDAPDistinguishedName, connectors: Connectors, asyncConfig: AsyncConfig, console: Console) -> Future<Void> {
	var f = asyncConfig.eventLoop.newSucceededFuture(result: ())
	
	/* To Google */
	if toSourceIds.contains(.google) {
		f = f.thenThrowing{ throw BasicValidationError("Cannot sync from Google to Google…") }
	}
	
	/* To GitHub */
	if toSourceIds.contains(.github) {
		f = f.thenThrowing{ throw NotImplementedError() }
	}
	
	/* To LDAP */
	if toSourceIds.contains(.ldap) {
		f = f.then{ syncFromGoogleToLDAP(users: users, baseDN: baseDN, connectors: connectors, asyncConfig: asyncConfig, console: console) }
	}
	
	return f
}

/** Compute the users to create on LDAP, asks for confirmation if some users
should be created, create them if users says ok, print the created users and
their passwords after creation.

- returns: The mapping dn<->password that has been created. */
private func syncFromGoogleToLDAP(users: [SourceId: [User]], baseDN: LDAPDistinguishedName, connectors: Connectors, asyncConfig: AsyncConfig, console: Console) -> Future<Void> {
	/* TODO: User deletion. Currently we’re append only. */
	let ldapUsers = users[.ldap]!
	let googleUsers = users[.google]!
	let ldapDNUsers = ldapUsers.compactMap{ $0.distinguishedNameIdVariant() }
	let googleDNUsers = googleUsers.compactMap{ $0.distinguishedNameIdVariant() }
	guard ldapUsers.count == ldapDNUsers.count && googleUsers.count == googleDNUsers.count else {
		return asyncConfig.eventLoop.newFailedFuture(error: InternalError(message: "Got users who could not be converted to DN variant."))
	}
	
	let usersToCreate = Set(googleDNUsers).subtracting(Set(ldapDNUsers))
	guard usersToCreate.count > 0 else {return asyncConfig.eventLoop.newSucceededFuture(result: ())}
	
	let usersToCreateAsText = usersToCreate
		.reduce("".consoleText(), { $0 + "   ".consoleText() + ($1.email?.stringValue ?? "<Unknown email>").consoleText() + ConsoleText.newLine })
	let msg =
		"Will create the following users on LDAP:" + ConsoleText.newLine +
		 usersToCreateAsText +
		"Do you want to continue?"
	guard console.confirm(msg) else {
		return asyncConfig.eventLoop.newFailedFuture(error: UserAbortedError())
	}
	
	let ldapUsersToCreate = usersToCreate.compactMap{ try? $0.ldapInetOrgPerson(baseDN: baseDN) }
	let createUsersOperation = CreateLDAPObjectsOperation(users: ldapUsersToCreate, connector: connectors.ldapConnector)
	return asyncConfig.eventLoop
	.future(from: createUsersOperation, queue: asyncConfig.operationQueue, resultRetriever: { op -> [LDAPObject] in
		let successfulCreationsIndex = op.errors.enumerated().filter{ $0.element == nil }.map{ $0.offset }
		return successfulCreationsIndex.map{ op.objects[$0] }
	})
	.then{ createdLDAPObjects -> Future<[String: String]> in
		let changePasswordsOperation = ModifyLDAPPasswordsOperation(objects: createdLDAPObjects, connector: connectors.ldapConnector)
		return asyncConfig.eventLoop.future(from: changePasswordsOperation, queue: asyncConfig.operationQueue, resultRetriever: { op in op.passwords })
	}
	.map{ passwords in
		console.print("Generated the following users on LDAP:")
		for (dn, password) in passwords {
			console.print("   " + dn + ": " + password)
		}
		return ()
	}
}

private func usersFromGoogle(connector: GoogleJWTConnector, searchedDomain: String, baseDN: LDAPDistinguishedName, asyncConfig: AsyncConfig) -> Future<(SourceId, [User])> {
	let searchOp = SearchGoogleUsersOperation(searchedDomain: searchedDomain, query: "isSuspended=false", googleConnector: connector)
	return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: {
		(.google, try $0.result.get().map{ User(googleUser: $0, baseDN: baseDN) })
	})
}

private func usersFromLDAP(connector: LDAPConnector, baseDN: LDAPDistinguishedName, asyncConfig: AsyncConfig) -> Future<(SourceId, [User])> {
	let searchOp = SearchLDAPOperation(ldapConnector: connector, request: LDAPSearchRequest(scope: .children, base: baseDN, searchQuery: nil, attributesToFetch: nil))
	return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue).map{
		(.ldap, $0.results.compactMap{ LDAPInetOrgPersonWithObject(object: $0) }.compactMap{ User(ldapInetOrgPersonWithObject: $0) })
	}
}
#endif
