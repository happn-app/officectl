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



struct Connectors {
	
	var ldapConnector: LDAPConnector!
	var googleConnector: GoogleJWTConnector!
	
	init() {
	}
	
}

func sync(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let asyncConfig: AsyncConfig = try context.container.make()
	
	var connectors = Connectors()
	var sourceId2FutureUsers = [SourceId: EventLoopFuture<(SourceId, [User])>]()
	
	
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
		guard let baseDNString = f.getString(name: "ldap-base-dn") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The \"ldap-base-dn\" option is required when syncing to or from LDAP"])
		}
		guard let peopleDNString = f.getString(name: "ldap-people-dn") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The \"ldap-people-dn\" option is required when syncing to or from LDAP"])
		}
		let baseDN = try LDAPDistinguishedName(string: baseDNString)
		if peopleDNString.isEmpty {ldapBasePeopleDN =                                                     baseDN}
		else                      {ldapBasePeopleDN = try LDAPDistinguishedName(string: peopleDNString) + baseDN}
	} else {
		ldapBasePeopleDN = nil
	}
	if fromSourceId == .google || toSourceIds.contains(.google) {
		guard let d = f.getString(name: "google-domain") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The \"google-domain\" option is required when syncing to or from Google"])
		}
		googleDomain = d
	} else {
		googleDomain = nil
	}
	
	/* *** Connect sources connectors and retrieve all (future) users from required sources *** */
	for s in [fromSourceId] + toSourceIds {
		guard sourceId2FutureUsers[s] == nil else {continue}
		switch s {
		case .google:
			guard let userBehalf = f.getString(name: "google-admin-email") else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The \"google-admin-email\" option is required when syncing Google"])
			}
			connectors.googleConnector = try GoogleJWTConnector(flags: f, userBehalf: userBehalf)
			sourceId2FutureUsers[s] =
				connectors.googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
				.then{ usersFromGoogle(connector: connectors.googleConnector, searchedDomain: googleDomain, baseDN: ldapBasePeopleDN, asyncConfig: asyncConfig) }
			
		case .ldap:
			connectors.ldapConnector = try LDAPConnector(flags: f)
			sourceId2FutureUsers[s] =
				connectors.ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
				.then{ usersFromLDAP(connector: connectors.ldapConnector, baseDN: ldapBasePeopleDN, asyncConfig: asyncConfig) }
			
		case .github: throw NSError(domain: "com.happn.officectl", code: 255, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
		}
	}
	
	/* *** Launch sync *** */
	let f = EventLoopFuture.reduce(into: [SourceId: [User]](), Array(sourceId2FutureUsers.values), eventLoop: asyncConfig.eventLoop, { currentValue, newValue in
		let (sourceId, users) = newValue
		currentValue[sourceId] = users
	})
	.then{ usersBySourceId -> EventLoopFuture<Void> in
		switch fromSourceId {
		case .google: return syncFromGoogle(to: toSourceIds, users: usersBySourceId, baseDN: ldapBasePeopleDN, connectors: connectors, asyncConfig: asyncConfig, console: context.console)
		case .ldap:   return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
		case .github: return asyncConfig.eventLoop.newFailedFuture(error: BasicValidationError("Cannot sync from GitHub (GitHub’s directory does not have enough information)"))
		}
	}
	return f
}

private func syncFromGoogle(to toSourceIds: [SourceId], users: [SourceId: [User]], baseDN: LDAPDistinguishedName, connectors: Connectors, asyncConfig: AsyncConfig, console: Console) -> EventLoopFuture<Void> {
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
		f = f
		.then{ syncFromGoogleToLDAP(users: users, baseDN: baseDN, connectors: connectors, asyncConfig: asyncConfig, console: console) }
		.map{ passwords in
			console.print("Generated the following users:")
			for (dn, password) in passwords {
				console.print("   " + dn + ": " + password)
			}
			return ()
		}
	}
	
	return f
}

/** - returns: The mapping dn<->password that has been created. */
private func syncFromGoogleToLDAP(users: [SourceId: [User]], baseDN: LDAPDistinguishedName, connectors: Connectors, asyncConfig: AsyncConfig, console: Console) -> EventLoopFuture<[String: String]> {
	/* TODO: User deletion. Currently we’re append only. */
	let ldapUsers = users[.ldap]!
	let googleUsers = users[.google]!
	let ldapDNUsers = ldapUsers.compactMap{ $0.distinguishedNameIdVariant() }
	let googleDNUsers = googleUsers.compactMap{ $0.distinguishedNameIdVariant() }
	guard ldapUsers.count == ldapDNUsers.count && googleUsers.count == googleDNUsers.count else {
		return asyncConfig.eventLoop.newFailedFuture(error: InternalError(message: "Got users who could not be converted to DN variant."))
	}
	
	let usersToCreate = Set(googleDNUsers).subtracting(Set(ldapDNUsers))
	let ldapUsersToCreate = usersToCreate.compactMap{ try? $0.ldapInetOrgPerson(baseDN: baseDN) }
	let createUsersOperation = CreateLDAPObjectsOperation(users: ldapUsersToCreate, connector: connectors.ldapConnector)
	
	let msg =
		"Will create the following users on LDAP:" + ConsoleText.newLine +
		usersToCreate.reduce("".consoleText(), { $0 + "   ".consoleText() + ($1.email?.stringValue ?? "<Unknown email>").consoleText() + ConsoleText.newLine }) +
		"Do you want to continue?"
	guard console.confirm(msg) else {
		return asyncConfig.eventLoop.newFailedFuture(error: UserAbortedError())
	}
	
	return asyncConfig.eventLoop
	.future(from: createUsersOperation, queue: asyncConfig.operationQueue, resultRetriever: { op -> [LDAPObject] in
		let successfulCreationsIndex = op.errors.enumerated().filter{ $0.element == nil }.map{ $0.offset }
		return successfulCreationsIndex.map{ op.objects[$0] }
	})
	.then{ createdLDAPObjects -> Future<[String: String]> in
		let changePasswordsOperation = ModifyLDAPPasswordsOperation(objects: createdLDAPObjects, connector: connectors.ldapConnector)
		return asyncConfig.eventLoop.future(from: changePasswordsOperation, queue: asyncConfig.operationQueue, resultRetriever: { op in op.passwords })
	}
}

private func usersFromGoogle(connector: GoogleJWTConnector, searchedDomain: String, baseDN: LDAPDistinguishedName, asyncConfig: AsyncConfig) -> EventLoopFuture<(SourceId, [User])> {
	let searchOp = SearchGoogleUsersOperation(searchedDomain: searchedDomain, query: "isSuspended=false", googleConnector: connector)
	return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: {
		(.google, try $0.result.successValueOrThrow().map{ User(googleUser: $0, baseDN: baseDN) })
	})
}

private func usersFromLDAP(connector: LDAPConnector, baseDN: LDAPDistinguishedName, asyncConfig: AsyncConfig) -> EventLoopFuture<(SourceId, [User])> {
	let searchOp = SearchLDAPOperation(ldapConnector: connector, request: LDAPSearchRequest(scope: .children, base: baseDN, searchQuery: nil, attributesToFetch: nil))
	return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: {
		(.ldap, try $0.results.successValueOrThrow().results.compactMap{ $0.inetOrgPerson }.compactMap{ User(ldapInetOrgPerson: $0) })
	})
}
