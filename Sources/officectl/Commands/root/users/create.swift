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
	let services = (try serviceIds?.map{ try sProvider.getDirectoryService(id: $0, container: context.container) } ?? sProvider.getAllServices(container: context.container)).filter{ $0.supportsUserCreation }
	guard !services.isEmpty else {
		return context.container.future()
	}
	
	if !yes {
		let confirmationPrompt: ConsoleText = (
			ConsoleText(stringLiteral: "Will try and create user with:") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "   - email:      \(email.stringValue)") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "   - first name: \(firstname)") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "   - last name:  \(lastname)") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "   - password:   \(password)") + ConsoleText.newLine +
			ConsoleText(stringLiteral: "On directories:") +
				(services
					.sorted{ $0.config.serviceId < $1.config.serviceId }
					.map{ ConsoleText.newLine + ConsoleText(stringLiteral: "   - \($0.config.serviceId) (\($0.config.serviceName))") }
				).reduce(ConsoleText(), +) + ConsoleText.newLine +
			ConsoleText(stringLiteral: "Is this ok?") + ConsoleText.newLine
		)
		guard context.console.confirm(confirmationPrompt) else {
			throw UserAbortedError()
		}
	}
	
	let futures = services.map{ service in
		context.container.future()
		.map{ _ in try nil2throw(service.logicalUser(fromEmail: email, hints: [.firstName: firstname, .lastName: lastname]), "Cannot create user for service \(service.config.serviceId)") }
		.flatMap{ user in try service.createUser(user, on: context.container) }
		.flatMap{ user in try service.changePasswordAction(for: user, on: context.container).start(parameters: password, weakeningMode: .alwaysInstantly, eventLoop: context.container.eventLoop) }
	}
	
	return Future.waitAll(futures, eventLoop: context.container.eventLoop)
	.map{ results in
		if !yes {
			context.console.info()
			context.console.info()
		}
		context.console.info("********* CREATION RESULTS *********")
		context.console.info()
		for (idx, result) in results.enumerated() {
			let serviceId = services[idx].config.serviceId
			switch result {
			case .success:            context.console.info("✅ \(serviceId): success")
			case .failure(let error): context.console.info("🛑 \(serviceId): got error \(error)")
			}
		}
	}
}
