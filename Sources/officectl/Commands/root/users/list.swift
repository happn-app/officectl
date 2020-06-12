/*
 * list.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit
import ServiceKit



struct UserListCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "list",
		abstract: "List all the users in a given directory."
	)
	
	@ArgumentParser.Flag(help: "For the directory services that supports it, do we filter out the suspended users?")
	var includeSuspendedUsers: Bool
	
	@ArgumentParser.Option(help: "The service id from which to retrieve the users.")
	var serviceId: String?
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) throws -> EventLoopFuture<Void> {
		let app = context.application
		let eventLoop = try app.services.make(EventLoop.self)
		
		let serviceProvider = app.officeKitServiceProvider
		let service = try serviceProvider.getUserDirectoryService(id: serviceId)
		
		try app.auditLogger.log(action: "List all users for service \(serviceId ?? "<inferred service>"), \(includeSuspendedUsers ? "" : "not ")including inactive users.", source: .cli)
		
		let usersFuture: EventLoopFuture<[String]>
		if let googleService: GoogleService = service.unbox() {
			usersFuture = try getUsersList(googleService: googleService, includeSuspendedUsers: includeSuspendedUsers, using: app.services)
		} else if let odService: OpenDirectoryService = service.unbox() {
			usersFuture = try getUsersList(openDirectoryService: odService, includeSuspendedUsers: includeSuspendedUsers, using: app.services)
		} else {
			throw InvalidArgumentError(message: "Unsupported service to list users from.")
		}
		
		return usersFuture
		.flatMap{ users -> EventLoopFuture<Void> in
			#warning("TODO: Use context.console to log stuff, not print.")
			var i = 1
			for user in users {
				print(user + ",", terminator: "")
				if i == 69 {print(); print(); i = 0}
				i += 1
			}
			print()
			return eventLoop.makeSucceededFuture(())
		}
	}
	
	private func getUsersList(googleService: GoogleService, includeSuspendedUsers: Bool, using services: Services) throws -> EventLoopFuture<[String]> {
		return try googleService.listAllUsers(using: services)
			.map{ $0.map{ googleService.shortDescription(fromUser: $0) } }
	}
	
	private func getUsersList(openDirectoryService: OpenDirectoryService, includeSuspendedUsers: Bool, using services: Services) throws -> EventLoopFuture<[String]> {
		return try openDirectoryService.listAllUsers(using: services)
			.map{ $0.map{ openDirectoryService.shortDescription(fromUser: $0) } }
	}
	
}
