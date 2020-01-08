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
import ServiceKit



func listUsers(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let eventLoop = app.eventLoopGroup.next()
	
	let serviceId = f.getString(name: "service-id")
	let serviceProvider = app.officeKitServiceProvider
	let service = try serviceProvider.getUserDirectoryService(id: serviceId)
	
	let includeInactiveUsers = f.getBool(name: "include-suspended-users")!
	
	try app.auditLogger.log(action: "List all users for service \(serviceId ?? "<inferred service>"), \(includeInactiveUsers ? "" : "not ")including inactive users.", source: .cli)
	
	let usersFuture: EventLoopFuture<[String]>
	if let googleService: GoogleService = service.unbox() {
		usersFuture = try getUsersList(googleService: googleService, includeInactiveUsers: includeInactiveUsers, using: app.services)
	} else if let odService: OpenDirectoryService = service.unbox() {
		usersFuture = try getUsersList(openDirectoryService: odService, includeInactiveUsers: includeInactiveUsers, using: app.services)
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

private func getUsersList(googleService: GoogleService, includeInactiveUsers: Bool, using services: Services) throws -> EventLoopFuture<[String]> {
	return try googleService.listAllUsers(using: services)
	.map{ $0.map{ googleService.shortDescription(fromUser: $0) } }
}

private func getUsersList(openDirectoryService: OpenDirectoryService, includeInactiveUsers: Bool, using services: Services) throws -> EventLoopFuture<[String]> {
	return try openDirectoryService.listAllUsers(using: services)
	.map{ $0.map{ openDirectoryService.shortDescription(fromUser: $0) } }
}
