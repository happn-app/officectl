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



func usersCreate(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let eventLoop = try app.services.make(EventLoop.self)
	
	let yes = f.getBool(name: "yes")!
	let emailStr = f.getString(name: "email")!
	let lastname = f.getString(name: "lastname")!
	let firstname = f.getString(name: "firstname")!
	let password = f.getString(name: "password") ?? generateRandomPassword()
	let serviceIds = f.getString(name: "service-ids")?.split(separator: ",").map(String.init)
	
	guard let email = Email(string: emailStr) else {
		throw InvalidArgumentError(message: "Invalid email \(emailStr)")
	}
	
	let sProvider = app.officeKitServiceProvider
	let services = try Array(sProvider.getUserDirectoryServices(ids: serviceIds.flatMap(Set.init)).filter{ $0.supportsUserCreation })
	guard !services.isEmpty else {
		context.console.warning("Nothing to do.")
		return eventLoop.future()
	}
	
	let users = services.map{ s in Result{ try s.logicalUser(fromEmail: email, hints: [.firstName: firstname, .lastName: lastname, .password: password], servicesProvider: sProvider) } }
	
	var skippedSomeUsers = false
	for (idx, user) in users.enumerated() {
		if let error = user.failureValue {
			skippedSomeUsers = true
			context.console.warning("⚠️ Skipping service \(services[idx].config.serviceId) because the creation of the logical user failed for this service (\(error)).")
		}
	}
	guard users.contains(where: { $0.successValue != nil }) else {
		context.console.warning("Nothing to do.")
		return eventLoop.future()
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
							ConsoleText(stringLiteral: service.shortDescription(fromUser: user))
					}
				).reduce(ConsoleText(), +) + ConsoleText.newLine +
			ConsoleText.newLine + ConsoleText(stringLiteral: "Is this ok?")
		)
		guard context.console.confirm(confirmationPrompt) else {
			throw UserAbortedError()
		}
	}
	
	try app.auditLogger.log(action: "Creating user with email “\(email.stringValue)”, first name “\(firstname)”, last name “\(lastname)” on services ids \(serviceIds?.joined(separator: ",") ?? "<all services>").", source: .cli)
	
	struct SkippedUser : Error {}
	let futures = users.enumerated().map{ serviceIdxAndUser -> EventLoopFuture<AnyDirectoryUser> in
		let (serviceIdx, userResult) = serviceIdxAndUser
		let service = services[serviceIdx]
		guard let user = userResult.successValue else {
			return eventLoop.future(error: SkippedUser())
		}
		
		return eventLoop.future()
		.flatMapThrowing{ _    in try service.createUser(user, using: app.services) }.flatMap{ $0 }
		.flatMapThrowing{ user in try service.changePasswordAction(for: user, using: app.services).start(parameters: password, weakeningMode: .alwaysInstantly, eventLoop: eventLoop).map{ user } }.flatMap{ $0 }
	}
	
	return EventLoopFuture.waitAll(futures, eventLoop: eventLoop)
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
			case .success(let user):         context.console.info("✅ \(serviceId): \(service.shortDescription(fromUser: user))")
			case .failure(let error):        context.console.info("🛑 \(serviceId): \(error)")
			}
		}
		context.console.info("Password for created users: \(password)")
	}
}
