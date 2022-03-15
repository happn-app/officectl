/*
 * delete.swift
 * officectl
 *
 * Created by François Lamboley on 2018/08/20.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit
import OfficeModel



struct UserDeleteCommand : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "delete",
		abstract: "Delete a user."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@ArgumentParser.Flag(help: "If set, this the users will be deleted without confirmation.")
	var yes = false
	
	@ArgumentParser.Option(name: .customLong("user-id"), help: "The tagged user ID of the user to delete.")
	var userID: String
	
	@ArgumentParser.Option(name: .customLong("service-ids"), help: "The service IDs on which to delete the user, comma-separated. If unset, the user will be deleted on all the services configured.")
	var serviceIDs: String?
	
	func run() async throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		
		let serviceIDs = self.serviceIDs?.split(separator: ",").map(String.init)
		
		let sProvider = app.officeKitServiceProvider
		let services = try Array(sProvider.getUserDirectoryServices(ids: serviceIDs.flatMap(Set.init)).filter{ $0.supportsUserDeletion })
		guard !services.isEmpty else {
			context.console.warning("Nothing to do.")
			return
		}
		
		let msu = try await MultiServicesUser.fetch(from: AnyDSUIDPair(taggedID: TaggedID(string: userID), servicesProvider: sProvider), in: Set(services), using: app.services)
		for (id, error) in msu.errorsByServiceID {
			app.console.warning("⚠️ Skipping service ID \(id) because I cannot get the user from this service. Error is \(error)")
		}
		guard msu.itemsByService.values.contains(where: { $0 != nil }) else {
			context.console.info("Nothing to do.")
			return
		}
		
		if !yes {
			let confirmationPrompt: ConsoleText = (
				ConsoleText(stringLiteral: "Will try and delete the user on these services:") + ConsoleText.newLine +
				(msu.itemsByService.sorted(by: { $0.key.config.serviceID < $1.key.config.serviceID })
					.map{ serviceAndUserIDPair in
						let (service, optionalUserIDPair) = serviceAndUserIDPair
						guard let uidPair = optionalUserIDPair else {
							return ConsoleText()
						}
						return (
							ConsoleText.newLine +
							ConsoleText(stringLiteral: "   - \(service.config.serviceID) (\(service.config.serviceName)): ") +
							ConsoleText(stringLiteral: service.shortDescription(fromUser: uidPair.user))
						)
					}
				).reduce(ConsoleText(), +) + ConsoleText.newLine +
				ConsoleText.newLine + ConsoleText(stringLiteral: "Is this ok?")
			)
			guard context.console.confirm(confirmationPrompt) else {
				throw UserAbortedError()
			}
		}
		
		let deletionResults = await msu.itemsByService.compactMapValues{ $0 }.concurrentMap{ service, uidPair in
			return await (service, Result{ try await service.deleteUser(uidPair.user, using: app.services) })
		}
		
		guard !deletionResults.isEmpty else {
			return
		}
		
		if !self.yes {
			context.console.info()
			context.console.info()
		}
		context.console.info("********* DELETION RESULTS *********")
		for (service, result) in deletionResults {
			switch result {
				case .success:            context.console.info("✅ \(service.config.serviceID): deleted")
				case .failure(let error): context.console.info("🛑 \(service.config.serviceID): \(error)")
			}
		}
	}
	
}
