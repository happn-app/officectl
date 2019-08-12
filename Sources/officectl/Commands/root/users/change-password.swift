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
	let services = (try serviceIds?.map{ try sProvider.getDirectoryService(id: $0, container: context.container) } ?? sProvider.getAllServices(container: context.container)).filter{ $0.supportsUserCreation }
	guard !services.isEmpty else {
		context.console.warning("Nothing to do.")
		return context.container.future()
	}
	
	let userId = try FullUserId(string: userIdStr, container: context.container)
	let (service, user) = try (userId.service, userId.service.logicalUser(fromUserId: userId.id, hints: [:]))
	
	let passwordResets = try sProvider
		.getAllServices(container: context.container)
		.filter{ $0.supportsPasswordChange }
		.map{ ResetPasswordActionAndService(destinationService: $0, sourceUser: user, sourceService: service, container: context.container) }
	
	/* Let’s ask for the new password */
	let newPass             = context.console.ask("New password: ", isSecure: true)
	let newPassConfirmation = context.console.ask("New password (again): ", isSecure: true)
	guard newPass == newPassConfirmation else {throw InvalidArgumentError(message: "Try again")}
	
	/* Verify none of the resets are already executing (highly improbable that
	 * they are in the current state of things, but who knows, maybe one day
	 * we’ll check in a db!). */
	guard !passwordResets.reduce(false, { $0 || $1.resetAction.successValue?.resetAction.isExecuting ?? false }) else {
		throw OperationAlreadyInProgressError()
	}
	
	try context.container.make(AuditLogger.self).log(action: "Changing password of \(userIdStr) on services ids \(serviceIds?.joined(separator: ",") ?? "<all services>").", source: .cli)
	
	let futures = passwordResets.map{ passwordReset -> Future<Void> in
		switch passwordReset.resetAction {
		case .success(let userAndAction): return userAndAction.resetAction.start(parameters: newPass, weakeningMode: .alwaysInstantly, eventLoop: context.container.eventLoop)
		case .failure(let error):         return context.container.future(error: error)
		}
	}
	
	return Future.waitAll(futures, eventLoop: context.container.eventLoop)
	.map{ results in
		context.console.info()
		context.console.info("********* PASSWORD CHANGES RESULTS *********")
		for (idx, result) in results.enumerated() {
			let service = passwordResets[idx].service
			let serviceId = service.config.serviceId
			let serviceName = service.config.serviceName
			switch result {
			case .success:            context.console.info("✅ \(serviceId) (\(serviceName))")
			case .failure(let error): context.console.info("🛑 \(serviceId) (\(serviceName): \(error)")
			}
		}
	}
}
