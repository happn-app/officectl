/*
 * change-password.swift
 * officectl
 *
 * Created by François Lamboley on 2019/7/13.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func usersChangePassword(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	let userIdStr = f.getString(name: "user-id")!
	let serviceIds = f.getString(name: "service-ids")?.split(separator: ",").map(String.init)
	
	let sProvider = try context.container.make(OfficeKitServiceProvider.self)
	let services = try sProvider.getUserDirectoryServices(ids: serviceIds.flatMap(Set.init)).filter{ $0.supportsUserCreation }
	guard !services.isEmpty else {
		context.console.warning("Nothing to do.")
		return context.container.future()
	}
	
	/* Let’s ask for the new password */
	let newPass             = context.console.ask("New password: ", isSecure: true)
	let newPassConfirmation = context.console.ask("New password (again): ", isSecure: true)
	guard newPass == newPassConfirmation else {throw InvalidArgumentError(message: "Try again")}
	
	let dsuIdPair = try AnyDSUIdPair(string: userIdStr, servicesProvider: context.container.make())
	return try MultiServicesPasswordReset.fetch(from: dsuIdPair, in: sProvider.getAllUserDirectoryServices(), on: context.container)
	.flatMap{ passwordResets in
		try context.container.make(AuditLogger.self).log(action: "Changing password of \(dsuIdPair.taggedId) on services ids \(serviceIds?.joined(separator: ",") ?? "<all services>").", source: .cli)
		return try passwordResets.start(newPass: newPass, weakeningMode: .alwaysInstantly, eventLoop: context.container.eventLoop)
		.map{ results in
			context.console.info()
			context.console.info("********* PASSWORD CHANGES RESULTS *********")
			for (service, result) in results {
				let serviceId = service.config.serviceId
				let serviceName = service.config.serviceName
				switch result {
				case .success:            context.console.info("✅ \(serviceId) (\(serviceName))")
				case .failure(let error): context.console.info("🛑 \(serviceId) (\(serviceName): \(error)")
				}
			}
		}
	}
}
