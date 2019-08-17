/*
 * create.swift
 * officectl
 *
 * Created by François Lamboley on 2019/7/13.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func usersCreate(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	let yes = f.getBool(name: "yes")!
	let emailStr = f.getString(name: "email")!
	let lastname = f.getString(name: "lastname")!
	let firstname = f.getString(name: "firstname")!
	let password = f.getString(name: "password") ?? generateRandomPassword()
	let serviceIds = f.getString(name: "service-ids")?.split(separator: ",").map(String.init)
	
	guard let email = Email(string: emailStr) else {
		throw InvalidArgumentError(message: "Invalid email \(emailStr)")
	}
	
	let sProvider = try context.container.make(OfficeKitServiceProvider.self)
	let services = (try serviceIds?.map{ try sProvider.getDirectoryService(id: $0) } ?? sProvider.getAllServices()).filter{ $0.supportsUserCreation }
	guard !services.isEmpty else {
		context.console.warning("Nothing to do.")
		return context.container.future()
	}
	
	let users = services.map{ s in Result{ try s.logicalUser(fromEmail: email, hints: [.firstName: firstname, .lastName: lastname, .password: password]) } }
	
	var skippedSomeUsers = false
	for (idx, user) in users.enumerated() {
		if let error = user.failureValue {
			skippedSomeUsers = true
			context.console.warning("⚠️ Skipping service \(services[idx].config.serviceId) because the creation of the logical user failed for this service (\(error)).")
		}
	}
	guard users.contains(where: { $0.successValue != nil }) else {
		context.console.warning("Nothing to do.")
		return context.container.future()
	}
	if skippedSomeUsers {context.console.info()}
	
	if !yes {
		let confirmationPrompt: ConsoleText = (
			ConsoleText(stringLiteral: "Will try and create user with these info:") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "   - email:      \(email.stringValue)") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "   - first name: \(firstname)") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "   - last name:  \(lastname)") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "   - password:   \(password)") + ConsoleText.newLine +
			ConsoleText.newLine +
			ConsoleText(stringLiteral: "Resolved to:") +
				(users.enumerated()
					.sorted{ services[$0.offset].config.serviceId < services[$1.offset].config.serviceId }
					.map{ serviceIdxAndUser in
						let (serviceIdx, userResult) = serviceIdxAndUser
						let service = services[serviceIdx]
						guard let user = userResult.successValue else {return ConsoleText()}
						return
							ConsoleText.newLine +
							ConsoleText(stringLiteral: "   - \(service.config.serviceId) (\(service.config.serviceName)): ") +
							ConsoleText(stringLiteral: service.shortDescription(from: user))
					}
				).reduce(ConsoleText(), +) + ConsoleText.newLine +
			ConsoleText.newLine + ConsoleText(stringLiteral: "Is this ok?")
		)
		guard context.console.confirm(confirmationPrompt) else {
			throw UserAbortedError()
		}
	}
	
	try context.container.make(AuditLogger.self).log(action: "Creating user with email “\(email.stringValue)”, first name “\(firstname)”, last name “\(lastname)” on services ids \(serviceIds?.joined(separator: ",") ?? "<all services>").", source: .cli)
	
	struct SkippedUser : Error {}
	let futures = users.enumerated().map{ serviceIdxAndUser -> Future<AnyDirectoryUser> in
		let (serviceIdx, userResult) = serviceIdxAndUser
		let service = services[serviceIdx]
		guard let user = userResult.successValue else {
			return context.container.future(error: SkippedUser())
		}
		
		return context.container.future()
		.flatMap{ _    in try service.createUser(user, on: context.container) }
		.flatMap{ user in try service.changePasswordAction(for: user, on: context.container).start(parameters: password, weakeningMode: .alwaysInstantly, eventLoop: context.container.eventLoop).map{ user } }
	}
	
	return Future.waitAll(futures, eventLoop: context.container.eventLoop)
	.map{ results in
		if !yes {
			context.console.info()
			context.console.info()
		}
		context.console.info("********* CREATION RESULTS *********")
		for (idx, result) in results.enumerated() {
			let service = services[idx]
			let serviceId = service.config.serviceId
			switch result {
			case .failure(_ as SkippedUser): (/* nop! (The user is skipped; this is a “normal” error and the error is shown before.) */)
			case .success(let user):         context.console.info("✅ \(serviceId): \(service.shortDescription(from: user))")
			case .failure(let error):        context.console.info("🛑 \(serviceId): \(error)")
			}
		}
		context.console.info("Password for created users: \(password)")
	}
}
