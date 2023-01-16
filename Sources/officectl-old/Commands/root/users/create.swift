/*
 * create.swift
 * officectl
 *
 * Created by François Lamboley on 2019/7/13.
 */

import Foundation

import ArgumentParser
import Email
import Vapor

import OfficeKit



struct UserCreateCommand : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "create",
		abstract: "Create a user on the given directories."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@ArgumentParser.Flag(help: "If set, this the users will be created without confirmation.")
	var yes = false
	
	@ArgumentParser.Option(help: "The email of the new user (we require the full email to infer the domain for the new user).")
	var email: Email
	
	@ArgumentParser.Option(help: "The firstName of the new user.")
	var firstName: String
	
	@ArgumentParser.Option(help: "The lastName of the new user.")
	var lastName: String
	
	@ArgumentParser.Option(help: "The password of the new user. If not set, an auto-generated pass will be used.")
	var password: String?
	
	@ArgumentParser.Option(name: .customLong("service-ids"), help: "The service IDs on which to create the user, comma-separated. If unset, the user will be created on all the services configured.")
	var serviceIDs: String?
	
	func run() async throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		
		let password = self.password ?? generateRandomPassword()
		let serviceIDs = self.serviceIDs?.split(separator: ",").map(String.init)
		
		let sProvider = app.officeKitServiceProvider
		let services = try Array(sProvider.getUserDirectoryServices(ids: serviceIDs.flatMap(Set.init)).filter{ $0.supportsUserCreation })
		guard !services.isEmpty else {
			context.console.warning("Nothing to do.")
			return
		}
		
		let users = services.map{ s in Result{ try s.logicalUser(fromEmail: email, hints: [.firstName: firstName, .lastName: lastName, .password: password], servicesProvider: sProvider) } }
		
		var skippedSomeUsers = false
		for (idx, user) in users.enumerated() {
			if let error = user.failureValue {
				skippedSomeUsers = true
				context.console.warning("⚠️ Skipping service \(services[idx].config.serviceID) because the creation of the logical user failed for this service (\(error)).")
			}
		}
		guard users.contains(where: { $0.successValue != nil }) else {
			context.console.warning("Nothing to do.")
			return
		}
		if skippedSomeUsers {context.console.info()}
		
		if !yes {
			let confirmationPrompt: ConsoleText = (
				ConsoleText(stringLiteral: "Will try and create user with these info:") + ConsoleText.newLine +
				ConsoleText(stringLiteral: "   - email:      \(email.rawValue)") + ConsoleText.newLine +
				ConsoleText(stringLiteral: "   - first name: \(firstName)") + ConsoleText.newLine +
				ConsoleText(stringLiteral: "   - last name:  \(lastName)") + ConsoleText.newLine +
				ConsoleText(stringLiteral: "   - password:   \(password)") + ConsoleText.newLine +
				ConsoleText.newLine +
				ConsoleText(stringLiteral: "Resolved to:") +
				(users.enumerated()
					.sorted{ services[$0.offset].config.serviceID < services[$1.offset].config.serviceID }
					.map{ serviceIdxAndUser in
						let (serviceIdx, userResult) = serviceIdxAndUser
						let service = services[serviceIdx]
						guard let user = userResult.successValue else {return ConsoleText()}
						return (
							ConsoleText.newLine +
							ConsoleText(stringLiteral: "   - \(service.config.serviceID) (\(service.config.serviceName)): ") +
							ConsoleText(stringLiteral: service.shortDescription(fromUser: user))
						)
					}
				).reduce(ConsoleText(), +) + ConsoleText.newLine +
				ConsoleText.newLine + ConsoleText(stringLiteral: "Is this ok?")
			)
			guard context.console.confirm(confirmationPrompt) else {
				throw UserAbortedError()
			}
		}
		
		try app.auditLogger.log(action: "Creating user with email “\(email.rawValue)”, first name “\(firstName)”, last name “\(lastName)” on services IDs \(serviceIDs?.joined(separator: ",") ?? "<all services>").", source: .cli)
		
		let results = await users
			.compactMap{ $0.successValue /* Failure case already handled */ }
			.enumerated()
			.concurrentMap{ serviceIdxAndUser -> (AnyUserDirectoryService, Result<AnyDirectoryUser, Error>) in
				let (serviceIdx, user) = serviceIdxAndUser
				let service = services[serviceIdx]
				
				return await (service, Result{
					let user = try await service.createUser(user, using: app.services)
					try await service.changePasswordAction(for: user, using: app.services).start(parameters: password, weakeningMode: .alwaysInstantly)
					return user
				})
			}
		
		if !self.yes {
			context.console.info()
			context.console.info()
		}
		context.console.info("********* CREATION RESULTS *********")
		for (service, result) in results {
			let serviceID = service.config.serviceID
			switch result {
				case .success(let user):         context.console.info("✅ \(serviceID): \(service.shortDescription(fromUser: user))")
				case .failure(let error):        context.console.info("🛑 \(serviceID): \(error)")
			}
		}
		context.console.info("Password for created users: \(password)")
	}
	
}