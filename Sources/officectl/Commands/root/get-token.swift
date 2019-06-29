/*
 * get-token.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func getToken(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	let asyncConfig = try context.container.make(AsyncConfig.self)
	let officeKitServiceProvider = try context.container.make(OfficeKitServiceProvider.self)
	
	let scopes = try nil2throw(f.getString(name: "scopes"), "scopes")
	let serviceId = try nil2throw(f.getString(name: "service-id"), "service-id")
	
	let directoryService = try officeKitServiceProvider.getDirectoryService(id: serviceId, container: context.container)
	if let googleService: GoogleService = directoryService.unwrapped() {
		let googleConnector = try GoogleJWTConnector(key: googleService.serviceConfig.connectorSettings)
		let f = googleConnector.connect(scope: Set(scopes.components(separatedBy: ",")), asyncConfig: asyncConfig)
			.then{ _ -> Future<Void> in
				print(googleConnector.token!)
				return asyncConfig.eventLoop.newSucceededFuture(result: ())
		}
		return f
	}
	
	throw InvalidArgumentError(message: "Unsupported service to get a token from.")
}
