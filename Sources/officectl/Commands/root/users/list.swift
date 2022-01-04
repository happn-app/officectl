/*
 * list.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
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
	
	enum Format : String, Decodable, ExpressibleByArgument {
		
		case email = "email"
		case onePerLine = "one-per-line"
		
	}
	
	@ArgumentParser.Flag(help: "For the directory services that supports it, do we filter out the suspended users?")
	var includeSuspendedUsers = false
	
	@ArgumentParser.Option(help: "The service ID from which to retrieve the users.")
	var serviceID: String?
	
	@OptionGroup
	var globalOptions: OfficectlRootCommand.Options
	
	@ArgumentParser.Option
	var format: Format = .email
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		
		let serviceProvider = app.officeKitServiceProvider
		let service = try serviceProvider.getUserDirectoryService(id: serviceID)
		
		try app.auditLogger.log(action: "List all users for service \(serviceID ?? "<inferred service>"), \(includeSuspendedUsers ? "" : "not ")including inactive users.", source: .cli)
		
		let users: [String]
		if let googleService: GoogleService = service.unbox() {
			users = try await getUsersList(googleService: googleService, includeSuspendedUsers: includeSuspendedUsers, using: app.services)
		} else if let odService: OpenDirectoryService = service.unbox() {
			users = try await getUsersList(openDirectoryService: odService, includeSuspendedUsers: includeSuspendedUsers, using: app.services)
		} else if let hService: HappnService = service.unbox() {
			users = try await getUsersList(happnService: hService, includeSuspendedUsers: includeSuspendedUsers, using: app.services)
		} else {
			throw InvalidArgumentError(message: "Unsupported service to list users from.")
		}
		
		switch format {
			case .email:
				var i = 1
				for user in users {
					print(user + ",", terminator: "")
					if i == 69 {print(); print(); i = 0}
					i += 1
				}
				print()
				
			case .onePerLine:
				for user in users {
					print(user)
				}
		}
	}
	
	private func getUsersList(googleService: GoogleService, includeSuspendedUsers: Bool, using services: Services) async throws -> [String] {
		return try await googleService.listAllUsers(using: services)
			.map{ googleService.shortDescription(fromUser: $0) }
	}
	
	private func getUsersList(openDirectoryService: OpenDirectoryService, includeSuspendedUsers: Bool, using services: Services) async throws -> [String] {
		return try await openDirectoryService.listAllUsers(using: services)
			.map{ openDirectoryService.shortDescription(fromUser: $0) }
	}
	
	private func getUsersList(happnService: HappnService, includeSuspendedUsers: Bool, using services: Services) async throws -> [String] {
		return try await happnService.listAllUsers(using: services)
			.map{ happnService.shortDescription(fromUser: $0) }
	}
	
}
