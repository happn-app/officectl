/*
 * users--create.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser
import Email
import URLRequestOperation

import OfficeKit
import OfficeModelCore



struct Users_Create : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "create",
		abstract: "Create a user."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	@OptionGroup()
	var usersOptions: Users.Options
	
	@Option(help: "The email of the new user (we require the full email to infer the domain for the new user).")
	var email: Email
	
	@Option(help: "The first-name of the new user.")
	var firstName: String
	
	@Option(help: "The last-name of the new user.")
	var lastName: String
	
	@Option(help: "The password of the new user. If not set, an auto-generated pass will be used.")
	var password: String?
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let services = officectlOptions.officeKitServices.hashableUserServices(matching: usersOptions.serviceIDs)
			.filter{ $0.value.supportsUserCreation }
			.sorted(by: { $0.value.id.rawValue < $1.value.id.rawValue })
		
		guard !services.isEmpty else {
			officectlOptions.logger.info("No services match; nothing to do.")
			return
		}
		
		let password = password ?? generateRandomPassword()
		
		let usersAndServicesResults = services.map{ s in
			Result{
				let u = try s.value.logicalUser(fromUser: HintsUser(properties: [
					.emails: [email],
					.firstName: firstName,
					.lastName: lastName
				]))
				return UserAndServiceFrom(user: u, service: s.value)!
			}
		}
		
		var skippedSomeUsers = false
		for (idx, userAndServiceResult) in usersAndServicesResults.enumerated() {
			if let error = userAndServiceResult.failure {
				skippedSomeUsers = true
				officectlOptions.logger.warning("Skipping creation of user for service \(services[idx].id) because the creation of the logical user failed for this service.", metadata: [LMK.error: "\(error)"])
			}
		}
		if skippedSomeUsers {
			print()
		}
		
		let usersAndServices = usersAndServicesResults.compactMap(\.success)
		guard !usersAndServices.isEmpty else {
			print("********* CREATION RESULTS *********")
			officectlOptions.logger.info("Nothing to do.")
			return
		}
		
		URLRequestOperationConfig.logger = officectlOptions.logger
		URLRequestOperationConfig.maxRequestBodySizeToLog = .max
		URLRequestOperationConfig.maxResponseBodySizeToLog = .max
		
		if !officectlOptions.yes {
			/* Let’s confirm everything is ok before deleting the user. */
			var stderrStream = StderrStream()
			print("Will try and create user with these info:", to: &stderrStream)
			print("   - email:      \(email.rawValue)", to: &stderrStream)
			print("   - first name: \(firstName)", to: &stderrStream)
			print("   - last name:  \(lastName)", to: &stderrStream)
			print("   - password:   \(password)", to: &stderrStream)
			print(to: &stderrStream)
			print("Resolved to:", to: &stderrStream)
			for userAndService in usersAndServices {
				print("   - \(userAndService.shortDescription)", to: &stderrStream)
			}
			print("", to: &stderrStream)
			guard try UserConfirmation.confirmYesOrNo(inputFileHandle: .standardInput, outputStream: &stderrStream) else {
				throw ExitCode(1)
			}
		}
		
//		try app.auditLogger.log(action: "Creating user with email “\(email.rawValue)”, first name “\(firstName)”, last name “\(lastName)” on services IDs \(serviceIDs?.joined(separator: ",") ?? "<all services>").", source: .cli)
		
		let results = await usersAndServices
			.concurrentMap{ userAndService -> (serviceID: Tag, newUserAndServiceResult: Result<any UserAndService, Error>) in
				return await (userAndService.service.id, Result{
					let newUserAndService = try await userAndService.create()
					do    {try await newUserAndService.changePassword(to: password)}
					catch {officectlOptions.logger.warning("Failed changing password of user for service ID \(newUserAndService.service.id).", metadata: [LMK.error: "\(error)"])}
					return newUserAndService
				})
			}
		
		if !officectlOptions.yes {
			print()
			print()
		}
		print("********* CREATION RESULTS *********")
		for (serviceID, result) in results {
			switch result {
				case .success(let userAndService): print("✅ \(serviceID): \(userAndService.shortDescription)")
				case .failure(let error):          print("🛑 \(serviceID): \(error)")
			}
		}
		print("Password for created users: \(password)")
	}
	
}
