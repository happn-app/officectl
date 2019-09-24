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
	
	var service: AnyUserDirectoryService
	
	var usersToCreate: [AnyDirectoryUser]
	var usersToDelete: [AnyDirectoryUser]
	
}


func sync(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	guard let syncConfig = try context.container.make(OfficectlConfig.self).syncConfig else {
		throw InvalidArgumentError(message: "Won’t sync without a sync config.")
	}
	
	let authServiceId = try context.container.make(OfficectlConfig.self).officeKitConfig.authServiceConfig.serviceId
	let officeKitServiceProvider = try context.container.make(OfficeKitServiceProvider.self)
	
	let fromId = f.getString(name: "from")!
	let toIds = Set(f.getString(name: "to")!.split(separator: ",").map(String.init)).subtracting([fromId])
	guard !toIds.isEmpty else {
		/* If there is nothing in toIds, we are done! */
		return context.container.eventLoop.future()
	}
	
	try context.container.make(AuditLogger.self).log(action: "Computing sync from service \(fromId) to \(toIds.joined(separator: ",")).", source: .cli)
	
	let fromDirectory = try officeKitServiceProvider.getDirectoryService(id: fromId)
	let toDirectories = try toIds.map{ try officeKitServiceProvider.getDirectoryService(id: String($0)) }
	
	return try MultiServicesUser.fetchAll(in: Set([fromDirectory] + toDirectories), on: context.container).map{
		let (users, fetchErrorsByService) = $0
		guard fetchErrorsByService.count == 0 else {
			throw ErrorCollection(Array(fetchErrorsByService.values))
		}
		
		return try toDirectories.map{ toDirectory in
			let directoryBlacklist = syncConfig.blacklistsByServiceId[toDirectory.config.serviceId] ?? []
			let usersToCreate = try users.filter{ $0[toDirectory]   == .some(nil) }.compactMap{ try $0[fromDirectory]!?.hop(to: toDirectory).user }.filter{ !directoryBlacklist.contains(toDirectory.string(fromUserId: $0.userId)) }
			let usersToDelete =     users.filter{ $0[fromDirectory] == .some(nil) }.compactMap{     $0[toDirectory]!?.user                        }.filter{ !directoryBlacklist.contains(toDirectory.string(fromUserId: $0.userId)) }
			return ServiceSyncPlan(service: toDirectory, usersToCreate: usersToCreate, usersToDelete: usersToDelete)
		}
	}
	.map{ (plans: [ServiceSyncPlan]) -> [ServiceSyncPlan] in
		/* Let’s verify the user is ok with the plan */
		var textPlan = "********* SYNC PLAN *********" + ConsoleText.newLine
		for plan in plans.sorted(by: { $0.service.config.serviceName < $1.service.config.serviceName }) {
			textPlan += ConsoleText.newLine + ConsoleText.newLine + "*** For service \(plan.service.config.serviceName) (id=\(plan.service.config.serviceId))".consoleText() + ConsoleText.newLine
			
			var printedSomething = false
			if !plan.usersToCreate.isEmpty {
				printedSomething = true
				textPlan += ConsoleText.newLine + "   - Users creation:" + ConsoleText.newLine
				plan.usersToCreate.forEach{ textPlan += "      \(plan.service.shortDescription(from: $0))".consoleText() + ConsoleText.newLine }
			}
			if !plan.usersToDelete.isEmpty {
				printedSomething = true
				textPlan += ConsoleText.newLine + "   - Users deletion (currently not implemented):" + ConsoleText.newLine
				plan.usersToDelete.forEach{ textPlan += "      \(plan.service.shortDescription(from: $0))".consoleText() + ConsoleText.newLine }
			}
			if !printedSomething {
				textPlan += "   <Nothing to do for this service>" + ConsoleText.newLine
			}
		}
		textPlan += ConsoleText.newLine + ConsoleText.newLine + ConsoleText.newLine + "Do you want to continue?"
		guard context.console.confirm(textPlan) else {
			throw UserAbortedError()
		}
		return plans
	}
	.flatMap{ plans in
		/* Now let’s do the actual sync! */
		try context.container.make(AuditLogger.self).log(action: "Applying sync from service \(fromId) to \(toIds.joined(separator: ",")).", source: .cli)
		
		typealias UserSyncResult = (serviceId: String, userStr: String, creationResult: Result<String?, Error>)
		let futures = plans.flatMap{ plan in
			plan.usersToCreate.map{ user -> Future<UserSyncResult> in
				let serviceId = plan.service.config.serviceId
				let userStr = plan.service.shortDescription(from: user)
				do {
					/* Create the user */
					return try plan.service.createUser(user, on: context.container)
					.flatMap{ user in
						/* If the service we’re creating the user in is the auth
						 * service, we also set a password on the user. */
						guard serviceId == authServiceId else {return context.container.future(nil)}
						
						let newPass = generateRandomPassword()
						let changePassAction = try plan.service.changePasswordAction(for: user, on: context.container)
						return changePassAction.start(parameters: newPass, weakeningMode: .alwaysInstantly, eventLoop: context.container.eventLoop)
							.map{ newPass }
					}
					.map{ pass in Result<String?, Error>.success(pass) }.catchMap{ error in Result<String?, Error>.failure(error) }
					.map{ (serviceId, userStr, $0) }
				} catch {
					return context.container.eventLoop.future((serviceId, userStr, .failure(error)))
				}
			}
		}
		
		return Future.waitAll(futures, eventLoop: context.container.eventLoop)
		.map{ results in
			context.console.info()
			context.console.info("********* SYNC RESULTS *********")
			for result in results.sorted(by: { ($0.successValue?.serviceId ?? "") < ($1.successValue?.serviceId ?? "") }) {
				switch result {
				case .success(let success):
					let userCreationResult = success.creationResult
					switch userCreationResult {
					case .success(nil):       context.console.info("\(success.serviceId): created user \(success.userStr)", newLine: true)
					case .success(let pass?): context.console.info("\(success.serviceId): created user \(success.userStr) w/ pass \(pass)", newLine: true)
					case .failure(let error): context.console.error("\(success.serviceId): failed to create user \(success.userStr): \(error)", newLine: true)
					}
					
				case .failure(let error):
					context.console.error("Got error \(error) for a future that should not fail!", newLine: true)
				}
			}
			context.console.info()
		}
	}
}
