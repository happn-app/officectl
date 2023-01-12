/*
 * change-password.swift
 * officectl
 *
 * Created by François Lamboley on 2019/7/13.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit



struct UserChangePasswordCommand : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "change-password",
		abstract: "Change the password of a user."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@ArgumentParser.Option(name: .customLong("user-id"), help: "The tagged user ID of the user whose password needs to be reset.")
	var userID: String
	
	@ArgumentParser.Option(name: .customLong("service-ids"), help: "The service IDs on which to reset the password. If unset, the password will be reset on all the services configured.")
	var serviceIDs: String?
	
	func run() async throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		
		let userIDStr = userID
		let serviceIDs = self.serviceIDs?.split(separator: ",").map(String.init)
		
		let sProvider = app.officeKitServiceProvider
		let services = try sProvider.getUserDirectoryServices(ids: serviceIDs.flatMap(Set.init)).filter{ $0.supportsPasswordChange }
		guard !services.isEmpty else {
			context.console.warning("Nothing to do.")
			return
		}
		
		/* Let’s ask for the new password */
		let newPass             = context.console.ask("New password: ", isSecure: true)
		let newPassConfirmation = context.console.ask("New password (again): ", isSecure: true)
		guard newPass == newPassConfirmation else {throw InvalidArgumentError(message: "Try again")}
		
		let dsuIDPair = try AnyDSUIDPair(string: userIDStr, servicesProvider: sProvider)
		let resets = try await MultiServicesPasswordReset.fetch(from: dsuIDPair, in: services, using: app.services)
		
		try app.auditLogger.log(action: "Changing password of \(dsuIDPair.taggedID) on services IDs \(serviceIDs?.joined(separator: ",") ?? "<all services>").", source: .cli)
		let results = try await resets.start(newPass: newPass, weakeningMode: .alwaysInstantly)
		
		context.console.info()
		context.console.info("********* PASSWORD CHANGES RESULTS *********")
		for (service, result) in results {
			let serviceID = service.config.serviceID
			let serviceName = service.config.serviceName
			switch result {
				case .success:            context.console.info("✅ \(serviceID) (\(serviceName))")
				case .failure(let error): context.console.info("🛑 \(serviceID) (\(serviceName): \(error)")
			}
		}
	}
	
}
