/*
 * sync.swift
 * officectl
 *
 * Created by François Lamboley on 2023/06/09.
 */

import Foundation

import ArgumentParser
import OfficeModelCore

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
			let usersToCreate: [any User] = try users
				.filter{ user in
					guard let destinationUser = user[destinationService]!.success else {
						return false
					}
					return destinationUser == nil
				}                                                        /* Multi-users w/o a value in the destination directory. */
				.compactMap{ $0[sourceService]!.success.flatMap{ $0 } }  /* But w/ a value in the source directory. */
				.map{ try $0.logicalUser(in: destinationService.value) } /* Converted to destination directory. */
			
			let usersToDelete: [any User] = users
				.filter{
					guard let user = $0[sourceService]!.success else {
						return false
					}
					return user == nil
				}                                                            /* Multi-users w/o a value in the source directory. */
				.compactMap{ $0[destinationService]!.success.flatMap{ $0 } } /* But w/ a value in the destination directory. */
			
			return ServiceSyncPlan(service: destinationService.value, usersToCreate: usersToCreate, usersToDelete: usersToDelete)
		}
		
		/* If we have nothing to do, we tell it to the user and we stop there. */
		guard !plans.reduce([], { $0 + $1.usersToCreate + $1.usersToDelete }).isEmpty else {
			print("Everything is in sync.")
			return
		}
		
		/* Let’s verify the user is ok with the plan. */
		let newLine = "\n"
		var stderrStream = StderrStream()
		var textPlan = "********* SYNC PLAN *********" + newLine
		for plan in plans.sorted(by: { $0.service.name < $1.service.name }) {
			textPlan += newLine + newLine + "*** For service \(plan.service.name) (id=\(plan.service.id))" + newLine
			
			var printedSomething = false
			if !plan.usersToCreate.isEmpty {
				printedSomething = true
				textPlan += newLine + "   - Users creation:" + newLine
				plan.usersToCreateWithService.forEach{ textPlan += "      \($0.shortDescription)" + newLine }
			}
			if !plan.usersToDelete.isEmpty {
				printedSomething = true
				textPlan += newLine + "   - Users deletion:" + newLine
				plan.usersToDeleteWithService.forEach{ textPlan += "      \($0.shortDescription)" + newLine }
			}
			if !printedSomething {
				textPlan += "   <Nothing to do for this service>" + newLine
			}
		}
		textPlan += newLine + newLine + newLine + "Do you want to continue? "
		guard try UserConfirmation.confirmYesOrNo(prompt: textPlan, inputFileHandle: .standardInput, outputStream: &stderrStream) else {
			throw ExitCode(1)
		}
		
		/* Now let’s do the actual sync! */
//		try app.auditLogger.log(action: "Applying sync from service \(fromID) to \(toIDs.joined(separator: ",")).", source: .cli)
		
		await withTaskGroup(of: UserSyncResult.self, returning: Void.self, body: { group in
			for plan in plans {
				/* User creations */
				for userToCreate in plan.usersToCreateWithService {
					let userStr = userToCreate.shortDescription
					group.addTask{
						do {
							let user = try await userToCreate.create()
							
							/* If the service we’re creating the user in is the auth service, we create a password. */
							let newPass: String?
							if userToCreate.serviceID != authService?.id {
								newPass = nil
							} else {
								let p = generateRandomPassword()
								try await user.changePassword(to: generateRandomPassword())
								newPass = p
							}
							
							return UserSyncResult.create(serviceID: userToCreate.serviceID, userStr: userStr, password: newPass, error: nil)
						} catch {
							return UserSyncResult.create(serviceID: userToCreate.serviceID, userStr: userStr, password: nil, error: error)
						}
					}
				}
				/* User deletions */
				for userToDelete in plan.usersToDeleteWithService {
					let userStr = userToDelete.shortDescription
					group.addTask{
						do {
							try await userToDelete.delete()
							return UserSyncResult.delete(serviceID: userToDelete.serviceID, userStr: userStr, error: nil)
						} catch {
							return UserSyncResult.delete(serviceID: userToDelete.serviceID, userStr: userStr, error: error)
						}
					}
				}
			}
			
			/* Let’s print the results */
			var results = [UserSyncResult]()
			for await result in group {results.append(result)}
			
			print()
			print("********* SYNC RESULTS *********")
			for result in results.sorted() {
				switch result {
					case .create(serviceID: let serviceID, userStr: let userStr, password: nil, error: nil):       print("✅ \(serviceID): created user \(userStr)")
					case .create(serviceID: let serviceID, userStr: let userStr, password: let pass?, error: nil): print("✅ \(serviceID): created user \(userStr) w/ pass \(pass)")
					case .create(serviceID: let serviceID, userStr: let userStr, password: _, error: let error?):  print("🛑 \(serviceID): failed to create user \(userStr): \(error)")
					case .delete(serviceID: let serviceID, userStr: let userStr, error: nil):                      print("✅ \(serviceID): deleted user \(userStr)")
					case .delete(serviceID: let serviceID, userStr: let userStr, error: let error?):               print("🛑 \(serviceID): failed to delete user \(userStr): \(error)")
				}
			}
			print()
		})
	}
	
	private struct ServiceSyncPlan {
		
		var service: any UserService
		
		var usersToCreate: [any User]
		var usersToDelete: [any User]
		
		var usersToCreateWithService: [any UserAndService] {
			usersToCreate.map{ UserAndServiceFrom(user: $0, service: service)! }
		}
		var usersToDeleteWithService: [any UserAndService] {
			usersToDelete.map{ UserAndServiceFrom(user: $0, service: service)! }
		}
		
	}
	
	private enum UserSyncResult : Comparable {
		
		case create(serviceID: Tag, userStr: String, password: String?, error: Error?)
		case delete(serviceID: Tag, userStr: String, error: Error?)
		
		static func <(lhs: UserSyncResult, rhs: UserSyncResult) -> Bool {
			switch (lhs, rhs) {
				case (.create(serviceID: let lhsServiceID, userStr: let lhsUserStr, password: _, error: _),
						.create(serviceID: let rhsServiceID, userStr: let rhsUserStr, password: _, error: _)):
					if lhsServiceID == rhsServiceID {return lhsUserStr < rhsUserStr}
					return lhsServiceID.rawValue < rhsServiceID.rawValue
					
				case (.delete(serviceID: let lhsServiceID, userStr: let lhsUserStr, error: _),
						.delete(serviceID: let rhsServiceID, userStr: let rhsUserStr, error: _)):
					if lhsServiceID == rhsServiceID {return lhsUserStr < rhsUserStr}
					return lhsServiceID.rawValue < rhsServiceID.rawValue
					
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
