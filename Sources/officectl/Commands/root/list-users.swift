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
	let officeKitConfig = try context.container.make(OfficectlConfig.self).officeKitConfig
	
	let serviceId = f.getString(name: "service-id")
	let serviceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
	
	let includeInactiveUsers = f.getBool(name: "include-suspended-users")!
	
	let usersFuture: Future<[String]>
	if let googleConfig: GoogleServiceConfig = serviceConfig.unboxed() {
		usersFuture = try getUsersList(googleConfig: googleConfig, includeInactiveUsers: includeInactiveUsers, eventLoop: context.container.eventLoop)
	} else {
		throw InvalidArgumentError(message: "Unsupported service to list users from.")
	}
	
	return usersFuture
	.then{ users -> Future<Void> in
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

private func getUsersList(googleConfig: GoogleServiceConfig, includeInactiveUsers: Bool, eventLoop: EventLoop) throws -> Future<[String]> {
	_ = try nil2throw(googleConfig.connectorSettings.userBehalf, "Google User Behalf")
	
	let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
	return googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, eventLoop: eventLoop)
	.then{ _ -> Future<[String]> in
		#warning("lol hardcoded happn.fr spotted :P")
		let searchOp = SearchGoogleUsersOperation(searchedDomain: "happn.fr", query: includeInactiveUsers ? nil : "isSuspended=false", googleConnector: googleConnector)
		return Future<[String]>.future(from: searchOp, eventLoop: eventLoop, resultRetriever: { try $0.result.get().map{ $0.primaryEmail.stringValue } })
	}
}
