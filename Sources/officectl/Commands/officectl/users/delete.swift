/*
 * delete.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/23.
 */

import Foundation

import ArgumentParser
import Logging
import StreamReader

import OfficeKit



struct Delete : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Delete a user."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	@OptionGroup()
	var usersOptions: Users.Options
	@OptionGroup()
	var serviceSearchSelectionOptions: Officectl.ServiceSearchSelectionOptions
	
	@Argument
	var anyUserID: String
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let servicesActedOn = officectlOptions.officeKitServices.hashableUserServices(matching: usersOptions.serviceIDs)
		let servicesForUserSearch = officectlOptions.officeKitServices.hashableUserServices(matching: serviceSearchSelectionOptions.idSearchServices)
		
		guard !servicesActedOn.isEmpty else {
			officectlOptions.logger.info("No services match; nothing to do.")
			return
		}
		
		guard let userAndService = await UserAndServiceFrom(stringUserID: anyUserID, fromAny: servicesForUserSearch, propertiesToFetch: []) else {
			officectlOptions.logger.error("User cannot be found.")
			throw ExitCode(rawValue: 1)
		}
		
		/* Important: if properties to fetch does not contain the properties needed to infer the user ID from other users, the user on some services might fail to fetch.
		 * Concrete example: if a property in an LDAP directory is the GitHub ID of a user, this property **must** be fetched in order for the link to be made.
		 * To not take any risks of losing users, we just fetch all the properties on all the services. */
		let multiUser = try await MultiServicesUser.fetch(from: userAndService, in: servicesActedOn, propertiesToFetch: nil)
		for (id, error) in (multiUser.compactMap{ keyVal in keyVal.value.failure.flatMap{ (keyVal.key.value, $0) } }) {
			officectlOptions.logger.warning("Skipping deletion for service because the user cannot be fetched for this servie.", metadata: [LMK.serviceID: "\(id)", LMK.error: "\(error)"])
		}
		let usersAndServices = multiUser
			.compactMap{ keyVal in keyVal.value.success.flatMap{ $0 }.flatMap{ ($0, keyVal.key.value) } }
			.map{ userAndService in
				let (user, service) = userAndService
				return UserAndServiceFrom(user: user, service: service)!
			}
		guard !usersAndServices.isEmpty else {
			officectlOptions.logger.info("No users exist for successful services; nothing to do.")
			return
		}
		
		if !officectlOptions.yes {
			/* Let’s confirm everything is ok before deleting the user. */
			var stderrStream = StderrStream()
			print("Will try and delete the uesr on these services:", to: &stderrStream)
			for userAndService in usersAndServices {
				print("   - \(userAndService.shortDescription)", to: &stderrStream)
			}
			print("", to: &stderrStream)
			guard try UserConfirmation.confirmYesOrNo(inputFileHandle: .standardInput, outputStream: &stderrStream) else {
				throw ExitCode(1)
			}
		} else {
			officectlOptions.logger.info("Deleting user on selected services.", metadata: [LMK.userAndServices: .array(usersAndServices.map{ .string($0.shortDescription) })])
		}
		
		/* Doing the actual deletion! */
		let deletionResults = await usersAndServices.concurrentMap{ userAndService in
			await (userAndService.service, Result{ try await userAndService.delete() })
		}
		
		/* Printing the results. */
		print("********* DELETION RESULTS *********")
		for (service, result) in deletionResults {
			switch result {
				case .success:            print("✅ \(service.id): deleted")
				case .failure(let error): print("🛑 \(service.id): \(error)")
			}
		}
		guard !(deletionResults.contains{ $0.1.failure != nil }) else {
			throw ExitCode(1)
		}
	}
	
}
