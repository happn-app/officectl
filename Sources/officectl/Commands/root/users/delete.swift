/*
 * delete.swift
 * officectl
 *
 * Created by François Lamboley on 20/08/2018.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit



struct UserDeleteCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "delete",
		abstract: "Delete a user."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@ArgumentParser.Flag(help: "If set, this the users will be deleted without confirmation.")
	var yes = false
	
	@ArgumentParser.Option(help: "The tagged user id of the user to delete.")
	var userId: String
	
	@ArgumentParser.Option(help: "The service ids on which to delete the user, comma-separated. If unset, the user will be deleted on all the services configured.")
	var serviceIds: String?
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	func vaporRun(_ context: CommandContext) throws -> EventLoopFuture<Void> {
		let app = context.application
		let eventLoop = try app.services.make(EventLoop.self)
		
		let serviceIds = self.serviceIds?.split(separator: ",").map(String.init)
		
		let sProvider = app.officeKitServiceProvider
		let services = try Array(sProvider.getUserDirectoryServices(ids: serviceIds.flatMap(Set.init)).filter{ $0.supportsUserDeletion })
		guard !services.isEmpty else {
			context.console.warning("Nothing to do.")
			return eventLoop.future()
		}
		
		return try MultiServicesUser.fetch(from: AnyDSUIdPair(taggedId: TaggedId(string: userId), servicesProvider: sProvider), in: Set(services), using: app.services)
			.flatMap{ msu -> EventLoopFuture<[(String, Result<Void, Error>)]> in
				for (id, error) in msu.errorsByServiceId {
					app.console.warning("⚠️ Skipping service id \(id) because I cannot get the user from this service. Error is \(error)")
				}
				guard msu.itemsByService.values.contains(where: { $0 != nil }) else {
					context.console.info("Nothing to do.")
					return eventLoop.future([])
				}
				if !yes {
					let confirmationPrompt: ConsoleText = (
						ConsoleText(stringLiteral: "Will try and delete the user on these services:") + ConsoleText.newLine +
						(msu.itemsByService.sorted(by: { $0.key.config.serviceId < $1.key.config.serviceId })
							.map{ serviceAndUserIdPair in
								let (service, optionalUserIdPair) = serviceAndUserIdPair
								guard let uidPair = optionalUserIdPair else {
									return ConsoleText()
								}
								return
									ConsoleText.newLine +
									ConsoleText(stringLiteral: "   - \(service.config.serviceId) (\(service.config.serviceName)): ") +
									ConsoleText(stringLiteral: service.shortDescription(fromUser: uidPair.user))
							}
						).reduce(ConsoleText(), +) + ConsoleText.newLine +
						ConsoleText.newLine + ConsoleText(stringLiteral: "Is this ok?")
					)
					guard context.console.confirm(confirmationPrompt) else {
						return eventLoop.future(error: UserAbortedError())
					}
				}
				
				let futures = msu.itemsByService.compactMap{ serviceAndUserIdPair -> (String, EventLoopFuture<Void>)? in
					let (service, optionalUserIdPair) = serviceAndUserIdPair
					guard let uidPair = optionalUserIdPair else {
						return nil
					}
					do {
						return (service.config.serviceId, try service.deleteUser(uidPair.user, using: app.services))
					} catch {
						return (service.config.serviceId, eventLoop.future(error: error))
					}
				}
				return EventLoopFuture.waitAll(futures, eventLoop: eventLoop)
			}
			.map{ results in
				guard !results.isEmpty else {
					return
				}
				if !self.yes {
					context.console.info()
					context.console.info()
				}
				context.console.info("********* DELETION RESULTS *********")
				for (serviceId, result) in results {
					switch result {
					case .success:            context.console.info("✅ \(serviceId): deleted")
					case .failure(let error): context.console.info("🛑 \(serviceId): \(error)")
					}
				}
			}
	}
	
}
