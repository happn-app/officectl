/*
 * sync.swift
 * officectl
 *
 * Created by François Lamboley on 2023/06/09.
 */

import Foundation

import ArgumentParser

import OfficeKit
import LDAPOffice



struct Sync : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Sync users from a given service to one or multiple services."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	@Option(name: .customLong("from"), help: "The service ID to sync from.")
	var sourceServiceID: String
	
	@Option(name: .customLong("to"), help: "The comma-separated list of service IDs to sync to.")
	var destinationServiceIDs: String
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.officeKitServices
		
		let authService = officeKitServices.authService
		guard let sourceService = officeKitServices.hashableUserServices(matching: sourceServiceID).onlyElement else {
			officectlOptions.logger.error("Cannot find source service.", metadata: [LMK.serviceID: "\(sourceServiceID)"])
			throw ExitCode(1)
		}
		let destinationServices = officeKitServices.hashableUserServices(matching: destinationServiceIDs)
		guard !destinationServices.isEmpty else {
			/* If there is nothing in toIDs, we are done! */
			return
		}
		
//		try app.auditLogger.log(action: "Computing sync from service \(fromID) to \(toIDs.joined(separator: ",")).", source: .cli)
		
		let (users, fetchErrorsByService) = try await MultiServicesUser.fetchAll(
			in: destinationServices.union([sourceService]),
			includeSuspended: false,
			customFetchFilter: { userAndService in
				let ignoredUsers = officectlOptions.ignoredUsersByServices[userAndService.serviceID] ?? []
				return !ignoredUsers.contains(userAndService.taggedID.id)
			}
		)
		guard fetchErrorsByService.isEmpty else {
			throw ErrorCollection(Array(fetchErrorsByService.values))
		}
		let plans: [ServiceSyncPlan] = try destinationServices.map{ (destinationService: HashableUserService) -> ServiceSyncPlan in
			let usersToCreate: [any User] = []/* try users
				.filter{ user in
					/* Multi-users w/o a value in the destination directory */
					guard let destinationUser = user[destinationService]!.success else {
						return false
					}
					return destinationUser == nil
				}
				.compactMap{ $0[sourceService]!.success.flatMap{ $0 } }                /* W/ a value in the source directory */
				.map{ try destinationService.value.logicalUserID(fromUser: $0) }  /* Converted to destination directory */
			*/
			let usersToDelete: [any User] = users
				.filter{
					/* Multi-users w/o a value in the source directory */
					guard let user = $0[sourceService]!.success else {
						return false
					}
					return user == nil
				}
				.compactMap{ $0[destinationService]!.success.flatMap{ $0 } } /* W/ a value in the destination directory */
			
			return ServiceSyncPlan(service: destinationService.value, usersToCreate: usersToCreate, usersToDelete: usersToDelete)
		}
		
		/* If we have nothing to do, we tell it to the user and we stop there. */
		guard !plans.reduce([], { $0 + $1.usersToCreate + $1.usersToDelete }).isEmpty else {
			print("Everything is in sync.")
			return
		}
		
		/* Let’s verify the user is ok with the plan. */
		
#if false
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
#endif
	}
	
	private struct ServiceSyncPlan {
		
		var service: any UserService
		
		var usersToCreate: [any User]
		var usersToDelete: [any User]
		
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
