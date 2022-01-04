/*
 * sync.swift
 * officectl
 *
 * Created by François Lamboley on 2018/07/13.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit



struct SyncCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "sync",
		abstract: "Sync users from a given service to one or multiple services. In the future, will also sync groups."
	)
	
	@ArgumentParser.Option(help: "The service ID to sync from.")
	var from: String
	
	@ArgumentParser.Option(help: "The list of services IDs to sync to.")
	var to: [String]
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient, especially for logging/retrieving user input from the Console. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		
		guard let syncConfig = app.officectlConfig.syncConfig else {
			throw InvalidArgumentError(message: "Won’t sync without a sync config.")
		}
		
		let authServiceID = app.officeKitConfig.authServiceConfig.serviceID
		let officeKitServiceProvider = app.officeKitServiceProvider
		
		let fromID = from
		let toIDs = Set(to).subtracting([fromID])
		guard !toIDs.isEmpty else {
			/* If there is nothing in toIDs, we are done! */
			return
		}
		
		try app.auditLogger.log(action: "Computing sync from service \(fromID) to \(toIDs.joined(separator: ",")).", source: .cli)
		
		let fromDirectory = try officeKitServiceProvider.getUserDirectoryService(id: fromID)
		let toDirectories = try toIDs.map{ try officeKitServiceProvider.getUserDirectoryService(id: String($0)) }
		
		let (users, fetchErrorsByService) = try await MultiServicesUser.fetchAll(in: Set([fromDirectory] + toDirectories), using: app.services)
		guard fetchErrorsByService.count == 0 else {
			throw ErrorCollection(Array(fetchErrorsByService.values))
		}
		
		let plans: [ServiceSyncPlan] = try toDirectories.map{ toDirectory in
			let toDirectoryBlacklist   = syncConfig.blacklistsByServiceID[toDirectory.config.serviceID]   ?? []
			let fromDirectoryBlacklist = syncConfig.blacklistsByServiceID[fromDirectory.config.serviceID] ?? []
			
			let usersToCreate = try users
				.filter{ $0[toDirectory] == .some(nil) }                                                      /* Multi-users w/o a value in the destination directory */
				.compactMap{ $0[fromDirectory]! }                                                             /* W/ a value in the source directory */
				.filter{ !fromDirectoryBlacklist.contains(fromDirectory.string(fromUserID: $0.user.userID)) } /* Not blacklisted from source */
				.map{ try $0.hop(to: toDirectory).user }                                                      /* Converted to destination directory */
				.filter{ !toDirectoryBlacklist.contains(toDirectory.string(fromUserID: $0.userID)) }          /* Not blacklisted in destination either */
			
			let usersToDelete = users
				.filter{ $0[fromDirectory] == .some(nil) }                                           /* Multi-users w/o a value in the source directory */
				.compactMap{ $0[toDirectory]!?.user }                                                /* W/ a value in the destination directory */
				.filter{ !toDirectoryBlacklist.contains(toDirectory.string(fromUserID: $0.userID)) } /* Not blacklisted in destination */
			
			return ServiceSyncPlan(service: toDirectory, usersToCreate: usersToCreate, usersToDelete: usersToDelete)
		}
		
		/* Let’s verify the user is ok with the plan */
		guard !plans.reduce([], { $0 + $1.usersToCreate + $1.usersToDelete }).isEmpty else {
			context.console.info("Everything is in sync.")
			return
		}
		
		var textPlan = "********* SYNC PLAN *********" + ConsoleText.newLine
		for plan in plans.sorted(by: { $0.service.config.serviceName < $1.service.config.serviceName }) {
			textPlan += ConsoleText.newLine + ConsoleText.newLine + "*** For service \(plan.service.config.serviceName) (id=\(plan.service.config.serviceID))".consoleText() + ConsoleText.newLine
			
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
		
		/* Now let’s do the actual sync! */
		try app.auditLogger.log(action: "Applying sync from service \(fromID) to \(toIDs.joined(separator: ",")).", source: .cli)
		
		await withTaskGroup(of: UserSyncResult.self, returning: Void.self, body: { group in
			for plan in plans {
				/* User creations */
				for userToCreate in plan.usersToCreate {
					let serviceID = plan.service.config.serviceID
					let userStr = plan.service.shortDescription(fromUser: userToCreate)
					group.addTask{
						do {
							let user = try await plan.service.createUser(userToCreate, using: app.services)
							
							/* If the service we’re creating the user in is the auth service, we create a password. */
							let newPass: String?
							if serviceID != authServiceID {
								newPass = nil
							} else {
								let pass = generateRandomPassword()
								newPass = pass
								let changePassAction = try plan.service.changePasswordAction(for: user, using: app.services)
								_ = try await changePassAction.start(parameters: pass, weakeningMode: .alwaysInstantly)
							}
							
							return UserSyncResult.create(serviceID: serviceID, userStr: userStr, password: newPass, error: nil)
						} catch {
							return UserSyncResult.create(serviceID: serviceID, userStr: userStr, password: nil, error: error)
						}
					}
				}
				/* User deletions */
				for userToDelete in plan.usersToDelete {
					let serviceID = plan.service.config.serviceID
					let userStr = plan.service.shortDescription(fromUser: userToDelete)
					group.addTask{
						do {
							try await plan.service.deleteUser(userToDelete, using: app.services)
							return UserSyncResult.delete(serviceID: serviceID, userStr: userStr, error: nil)
						} catch {
							return UserSyncResult.delete(serviceID: serviceID, userStr: userStr, error: error)
						}
					}
				}
			}
			
			/* Let’s print the results */
			var results = [UserSyncResult]()
			for await result in group {results.append(result)}
			
			context.console.info()
			context.console.info("********* SYNC RESULTS *********")
			for result in results.sorted() {
				switch result {
					case .create(serviceID: let serviceID, userStr: let userStr, password: nil, error: nil):       context.console.info("\(serviceID): created user \(userStr)", newLine: true)
					case .create(serviceID: let serviceID, userStr: let userStr, password: let pass?, error: nil): context.console.info("\(serviceID): created user \(userStr) w/ pass \(pass)", newLine: true)
					case .create(serviceID: let serviceID, userStr: let userStr, password: _, error: let error?):  context.console.error("\(serviceID): failed to create user \(userStr): \(error)", newLine: true)
					case .delete(serviceID: let serviceID, userStr: let userStr, error: nil):                      context.console.info("\(serviceID): deleted user \(userStr)", newLine: true)
					case .delete(serviceID: let serviceID, userStr: let userStr, error: let error?):               context.console.error("\(serviceID): failed to delete user \(userStr): \(error)", newLine: true)
				}
			}
			context.console.info()
		})
	}
	
	private struct ServiceSyncPlan {
		
		var service: AnyUserDirectoryService
		
		var usersToCreate: [AnyDirectoryUser]
		var usersToDelete: [AnyDirectoryUser]
		
	}
	
	private enum UserSyncResult : Comparable {
		
		case create(serviceID: String, userStr: String, password: String?, error: Error?)
		case delete(serviceID: String, userStr: String, error: Error?)
		
		static func <(lhs: UserSyncResult, rhs: UserSyncResult) -> Bool {
			switch (lhs, rhs) {
				case (.create(serviceID: let lhsServiceID, userStr: let lhsUserStr, password: _, error: _),
						.create(serviceID: let rhsServiceID, userStr: let rhsUserStr, password: _, error: _)):
					if lhsServiceID == rhsServiceID {return lhsUserStr < rhsUserStr}
					return lhsServiceID < rhsServiceID
					
				case (.delete(serviceID: let lhsServiceID, userStr: let lhsUserStr, error: _),
						.delete(serviceID: let rhsServiceID, userStr: let rhsUserStr, error: _)):
					if lhsServiceID == rhsServiceID {return lhsUserStr < rhsUserStr}
					return lhsServiceID < rhsServiceID
					
				case (.create, .delete):
					return false
					
				case (.delete, .create):
					return true
			}
		}
		
		static func ==(lhs: UserSyncResult, rhs: UserSyncResult) -> Bool {
			switch (lhs, rhs) {
				case (.create(serviceID: let lhsServiceID, userStr: let lhsUserStr, password: _, error: _),
						.create(serviceID: let rhsServiceID, userStr: let rhsUserStr, password: _, error: _)):
					return lhsServiceID == rhsServiceID && lhsUserStr == rhsUserStr
					
				case (.delete(serviceID: let lhsServiceID, userStr: let lhsUserStr, error: _),
						.delete(serviceID: let rhsServiceID, userStr: let rhsUserStr, error: _)):
					return lhsServiceID == rhsServiceID && lhsUserStr == rhsUserStr
					
				case (.create, .delete), (.delete, .create):
					return false
			}
		}
		
	}
	
}
