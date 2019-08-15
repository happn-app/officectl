/*
 * list-users.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func listUsers(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	let serviceId = f.getString(name: "service-id")
	let serviceProvider: OfficeKitServiceProvider = try context.container.make()
	let service = try serviceProvider.getDirectoryService(id: serviceId, container: context.container)
	
	let includeInactiveUsers = f.getBool(name: "include-suspended-users")!
	
	try context.container.make(AuditLogger.self).log(action: "List all users for service \(serviceId ?? "<inferred service>"), \(includeInactiveUsers ? "" : "not ")including inactive users.", source: .cli)
	
	let usersFuture: Future<[String]>
	if let googleService: GoogleService = service.unboxed() {
		usersFuture = try getUsersList(googleService: googleService, includeInactiveUsers: includeInactiveUsers, container: context.container)
	} else if let odService: OpenDirectoryService = service.unboxed() {
		usersFuture = try getUsersList(openDirectoryService: odService, includeInactiveUsers: includeInactiveUsers, container: context.container)
	} else {
		throw InvalidArgumentError(message: "Unsupported service to list users from.")
	}
	
	return usersFuture
	.then{ users -> Future<Void> in
		#warning("TODO: Use context.console to log stuff, not print.")
		var i = 1
		for user in users {
			print(user + ",", terminator: "")
			if i == 69 {print(); print(); i = 0}
			i += 1
		}
		print()
		return context.container.eventLoop.newSucceededFuture(result: ())
	}
}

private func getUsersList(googleService: GoogleService, includeInactiveUsers: Bool, container: Container) throws -> Future<[String]> {
	return try googleService.listAllUsers(on: container)
	.map{ $0.map{ googleService.shortDescription(from: $0) } }
}

private func getUsersList(openDirectoryService: OpenDirectoryService, includeInactiveUsers: Bool, container: Container) throws -> Future<[String]> {
	return try openDirectoryService.listAllUsers(on: container)
	.map{ $0.map{ openDirectoryService.shortDescription(from: $0) } }
}
