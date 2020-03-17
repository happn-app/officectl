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



private struct NoSyncActions : Error {}


private struct ServiceSyncPlan {
	
	var service: AnyUserDirectoryService
	
	var usersToCreate: [AnyDirectoryUser]
	var usersToDelete: [AnyDirectoryUser]
	
}


func sync(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let eventLoop = try app.services.make(EventLoop.self)
	
	guard let syncConfig = app.officectlConfig.syncConfig else {
		throw InvalidArgumentError(message: "Won’t sync without a sync config.")
	}
	
	let authServiceId = app.officeKitConfig.authServiceConfig.serviceId
	let officeKitServiceProvider = app.officeKitServiceProvider
	
	let fromId = f.getString(name: "from")!
	let toIds = Set(f.getString(name: "to")!.split(separator: ",").map(String.init)).subtracting([fromId])
	guard !toIds.isEmpty else {
		/* If there is nothing in toIds, we are done! */
		return eventLoop.future()
	}
	
	try app.auditLogger.log(action: "Computing sync from service \(fromId) to \(toIds.joined(separator: ",")).", source: .cli)
	
	let fromDirectory = try officeKitServiceProvider.getUserDirectoryService(id: fromId)
	let toDirectories = try toIds.map{ try officeKitServiceProvider.getUserDirectoryService(id: String($0)) }
	
	return try MultiServicesUser.fetchAll(in: Set([fromDirectory] + toDirectories), using: app.services).flatMapThrowing{
		let (users, fetchErrorsByService) = $0
		guard fetchErrorsByService.count == 0 else {
			throw ErrorCollection(Array(fetchErrorsByService.values))
		}
		
		return try toDirectories.map{ toDirectory in
			let toDirectoryBlacklist   = syncConfig.blacklistsByServiceId[toDirectory.config.serviceId]   ?? []
			let fromDirectoryBlacklist = syncConfig.blacklistsByServiceId[fromDirectory.config.serviceId] ?? []
			
			let usersToCreate = try users
				.filter{ $0[toDirectory] == .some(nil) }                                                      /* Multi-users w/o a value in the destination directory */
				.compactMap{ $0[fromDirectory]! }                                                             /* W/ a value in the source directory */
				.filter{ !fromDirectoryBlacklist.contains(fromDirectory.string(fromUserId: $0.user.userId)) } /* Not blacklisted from source */
				.map{ try $0.hop(to: toDirectory).user }                                                      /* Converted to destination directory */
				.filter{ !toDirectoryBlacklist.contains(toDirectory.string(fromUserId: $0.userId)) }          /* Not blacklisted in destination either */
			
			let usersToDelete = users
				.filter{ $0[fromDirectory] == .some(nil) }                                           /* Multi-users w/o a value in the source directory */
				.compactMap{ $0[toDirectory]!?.user }                                                /* W/ a value in the destination directory */
				.filter{ !toDirectoryBlacklist.contains(toDirectory.string(fromUserId: $0.userId)) } /* Not blacklisted in destination */
			
			return ServiceSyncPlan(service: toDirectory, usersToCreate: usersToCreate, usersToDelete: usersToDelete)
		}
	}
	.flatMapThrowing{ (plans: [ServiceSyncPlan]) -> [ServiceSyncPlan] in
		/* Let’s verify the user is ok with the plan */
		guard !plans.reduce([], { $0 + $1.usersToCreate + $1.usersToDelete }).isEmpty else {
			context.console.info("Everything is in sync.")
			throw NoSyncActions()
		}
		
		var textPlan = "********* SYNC PLAN *********" + ConsoleText.newLine
		for plan in plans.sorted(by: { $0.service.config.serviceName < $1.service.config.serviceName }) {
			textPlan += ConsoleText.newLine + ConsoleText.newLine + "*** For service \(plan.service.config.serviceName) (id=\(plan.service.config.serviceId))".consoleText() + ConsoleText.newLine
			
			var printedSomething = false
			if !plan.usersToCreate.isEmpty {
				printedSomething = true
				textPlan += ConsoleText.newLine + "   - Users creation:" + ConsoleText.newLine
				plan.usersToCreate.forEach{ textPlan += "      \(plan.service.shortDescription(fromUser: $0))".consoleText() + ConsoleText.newLine }
			}
			if !plan.usersToDelete.isEmpty {
				printedSomething = true
				textPlan += ConsoleText.newLine + "   - Users deletion:" + ConsoleText.newLine
				plan.usersToDelete.forEach{ textPlan += "      \(plan.service.shortDescription(fromUser: $0))".consoleText() + ConsoleText.newLine }
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
	.flatMapThrowing{ plans in
		/* Now let’s do the actual sync! */
		try app.auditLogger.log(action: "Applying sync from service \(fromId) to \(toIds.joined(separator: ",")).", source: .cli)
		
		let futures = plans.flatMap{ plan in
			plan.usersToCreate.map{ user -> EventLoopFuture<UserSyncResult> in
				let serviceId = plan.service.config.serviceId
				let userStr = plan.service.shortDescription(fromUser: user)
				/* Create the user */
				return eventLoop.future()
				.flatMapThrowing{ _ in try plan.service.createUser(user, using: app.services) }
				.flatMap{ $0 }
				.flatMapThrowing{ user in
					/* If the service we’re creating the user in is the auth
					 * service, we also set a password on the user. */
					guard serviceId == authServiceId else {return eventLoop.future(nil)}
					
					let newPass = generateRandomPassword()
					let changePassAction = try plan.service.changePasswordAction(for: user, using: app.services)
					return changePassAction.start(parameters: newPass, weakeningMode: .alwaysInstantly, eventLoop: eventLoop)
						.map{ newPass }
				}
				.flatMap{ $0 }
				.map{ pass in Result<String?, Error>.success(pass) }.flatMapErrorThrowing{ error in Result<String?, Error>.failure(error) }
				.map{ UserSyncResult.create(serviceId: serviceId, userStr: userStr, password: $0.successValue ?? nil, error: $0.failureValue) }
			}
			+
			plan.usersToDelete.map{ user -> EventLoopFuture<UserSyncResult> in
				let serviceId = plan.service.config.serviceId
				let userStr = plan.service.shortDescription(fromUser: user)
				/* Delete the user */
				return eventLoop.future()
				.flatMapThrowing{ _ in try plan.service.deleteUser(user, using: app.services) }
				.flatMap{ $0 }
				.map{ pass in Result<Void, Error>.success(()) }.flatMapErrorThrowing{ error in Result<Void, Error>.failure(error) }
				.map{ UserSyncResult.delete(serviceId: serviceId, userStr: userStr, error: $0.failureValue) }
			}
		}
		
		return EventLoopFuture.whenAllComplete(futures, on: eventLoop)
		.map{ resultsAll in
			let results = resultsAll.compactMap{ $0.successValue }
			let internalErrorFailures = resultsAll.compactMap{ $0.failureValue }
			
			context.console.info()
			context.console.info("********* SYNC RESULTS *********")
			for internalError in internalErrorFailures {
				context.console.error("Internal Error: Got error \(internalError) for a future that should not fail!", newLine: true)
			}
			for result in results.sorted() {
				switch result {
				case .create(serviceId: let serviceId, userStr: let userStr, password: nil, error: nil):       context.console.info("\(serviceId): created user \(userStr)", newLine: true)
				case .create(serviceId: let serviceId, userStr: let userStr, password: let pass?, error: nil): context.console.info("\(serviceId): created user \(userStr) w/ pass \(pass)", newLine: true)
				case .create(serviceId: let serviceId, userStr: let userStr, password: _, error: let error?):  context.console.error("\(serviceId): failed to create user \(userStr): \(error)", newLine: true)
				case .delete(serviceId: let serviceId, userStr: let userStr, error: nil):                      context.console.info("\(serviceId): deleted user \(userStr)", newLine: true)
				case .delete(serviceId: let serviceId, userStr: let userStr, error: let error?):               context.console.error("\(serviceId): failed to delete user \(userStr): \(error)", newLine: true)
				}
			}
			context.console.info()
		}
	}
	.flatMap{ $0 }
	.flatMapErrorThrowing{ error in
		guard error is NoSyncActions else {
			throw error
		}
		return ()
	}
}


private enum UserSyncResult : Comparable {
	
	case create(serviceId: String, userStr: String, password: String?, error: Error?)
	case delete(serviceId: String, userStr: String, error: Error?)
	
	static func <(lhs: UserSyncResult, rhs: UserSyncResult) -> Bool {
		switch (lhs, rhs) {
		case (.create(serviceId: let lhsServiceId, userStr: let lhsUserStr, password: _, error: _),
				.create(serviceId: let rhsServiceId, userStr: let rhsUserStr, password: _, error: _)):
			if lhsServiceId == rhsServiceId {return lhsUserStr < rhsUserStr}
			return lhsServiceId < rhsServiceId
			
		case (.delete(serviceId: let lhsServiceId, userStr: let lhsUserStr, error: _),
				.delete(serviceId: let rhsServiceId, userStr: let rhsUserStr, error: _)):
			if lhsServiceId == rhsServiceId {return lhsUserStr < rhsUserStr}
			return lhsServiceId < rhsServiceId
			
		case (.create, .delete):
			return false
			
		case (.delete, .create):
			return true
		}
	}
	
	static func ==(lhs: UserSyncResult, rhs: UserSyncResult) -> Bool {
		switch (lhs, rhs) {
		case (.create(serviceId: let lhsServiceId, userStr: let lhsUserStr, password: _, error: _),
				.create(serviceId: let rhsServiceId, userStr: let rhsUserStr, password: _, error: _)):
			return lhsServiceId == rhsServiceId && lhsUserStr == rhsUserStr
			
		case (.delete(serviceId: let lhsServiceId, userStr: let lhsUserStr, error: _),
				.delete(serviceId: let rhsServiceId, userStr: let rhsUserStr, error: _)):
			return lhsServiceId == rhsServiceId && lhsUserStr == rhsUserStr
			
		case (.create, .delete), (.delete, .create):
			return false
		}
	}
	
}
