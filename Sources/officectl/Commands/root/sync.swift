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



private struct ServiceSyncPlan {
	
	var service: AnyDirectoryService
	
	var usersToCreate: Set<AnyDirectoryUser>
	var usersToDelete: Set<AnyDirectoryUser>
	
}


func sync(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	let asyncConfig = try context.container.make(AsyncConfig.self)
	let officeKitServiceProvider = try context.container.make(OfficeKitServiceProvider.self)
	
	let fromId = f.getString(name: "from")!
	let toIds = Set(f.getString(name: "to")!.split(separator: ",").map(String.init)).subtracting([fromId])
	guard !toIds.isEmpty else {
		/* If there is nothing in toIds, we are done! */
		return asyncConfig.eventLoop.future()
	}
	
	let fromDirectory = try officeKitServiceProvider.getDirectoryService(id: fromId, container: context.container)
	let toDirectories = try toIds.map{ try officeKitServiceProvider.getDirectoryService(id: String($0), container: context.container) }
	
	return fromDirectory.listAllUsers().map{ Set($0) }
	.then{ sourceUsers -> Future<[ServiceSyncPlan]> in
		let futures = toDirectories.map{ toDirectory in
			return toDirectory.listAllUsers().map{ Set($0) }
			.map{ (currentDestinationUsers: Set<AnyDirectoryUser>) -> ServiceSyncPlan in
				let expectedDestinationUsers = try Set(sourceUsers.compactMap{ try toDirectory.logicalUser(from: $0, in: fromDirectory) })
				
				let usersToCreate = expectedDestinationUsers.subtracting(currentDestinationUsers)
				let usersToDelete = currentDestinationUsers.subtracting(expectedDestinationUsers)
				return ServiceSyncPlan(service: toDirectory, usersToCreate: usersToCreate, usersToDelete: usersToDelete)
			}
		}
		return Future.reduce([ServiceSyncPlan](), futures, eventLoop: asyncConfig.eventLoop, { $0 + [$1] })
	}
	.map{ (plans: [ServiceSyncPlan]) -> [ServiceSyncPlan] in
		/* Let’s verify the user is ok with the plan */
		var textPlan = ConsoleText.newLine + "********* SYNC PLAN *********" + ConsoleText.newLine
		for plan in plans {
			textPlan += ConsoleText.newLine + "*** For service \(plan.service.config.serviceName) (id=\(plan.service.config.serviceId))".consoleText() + ConsoleText.newLine
			
			var printedSomething = false
			if !plan.usersToCreate.isEmpty {
				printedSomething = true
				textPlan += "- Users creation:" + ConsoleText.newLine
				plan.usersToCreate.forEach{ textPlan += "   \($0)".consoleText() + ConsoleText.newLine }
			}
			if !plan.usersToDelete.isEmpty {
				printedSomething = true
				textPlan += "- Users deletion:" + ConsoleText.newLine
				plan.usersToDelete.forEach{ textPlan += "   \($0)".consoleText() + ConsoleText.newLine }
			}
			if !printedSomething {
				textPlan += "<Nothing to do for this service>" + ConsoleText.newLine
			}
		}
		textPlan += "Do you want to continue?"
		guard context.console.confirm(textPlan) else {
			throw UserAbortedError()
		}
		return plans
	}
	.then{ plans in
		/* Now let’s do the actual sync! */
		return asyncConfig.eventLoop.future()
	}
}

#if false
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
