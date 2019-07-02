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



func sync(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	#warning("TODO: Manage multiple domains")
	let asyncConfig = try context.container.make(AsyncConfig.self)
	let officeKitServiceProvider = try context.container.make(OfficeKitServiceProvider.self)
	
	let fromDirectory = try officeKitServiceProvider.getDirectoryService(id: f.getString(name: "from")!, container: context.container)
	let toDirectories = try Set(f.getString(name: "to")!.split(separator: ",")).map{ try officeKitServiceProvider.getDirectoryService(id: String($0), container: context.container) }
	
	/* *** Connect sources connectors and retrieve all (future) users from required sources *** */
	var serviceId2FutureUsers = [String: Future<(String, [AnyDirectoryUser])>]()
	for s in [fromDirectory] + toDirectories {
		guard serviceId2FutureUsers[s.config.serviceId] == nil else {continue}
		serviceId2FutureUsers[s.config.serviceId] = s.listAllUsers().map{ (s.config.serviceId, $0) }
	}
	
	/* *** Launch sync *** */
	let f = Future.reduce(into: [String: [AnyDirectoryUser]](), Array(serviceId2FutureUsers.values), eventLoop: asyncConfig.eventLoop, { currentValue, newValue in
		let (sourceId, users) = newValue
		currentValue[sourceId] = users
	})
	.then{ usersBySourceId -> Future<Void> in
		return asyncConfig.eventLoop.future()
//		switch fromDirectory.config.serviceId {
//		case .google: return syncFromGoogle(to: toSourceIds, users: usersBySourceId, baseDN: ldapBasePeopleDN, connectors: connectors, asyncConfig: asyncConfig, console: context.console)
//		case .ldap:   return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
//		case .github: return asyncConfig.eventLoop.newFailedFuture(error: BasicValidationError("Cannot sync from GitHub (GitHub’s directory does not have enough information)"))
//		}
	}
	return f
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
#endif
