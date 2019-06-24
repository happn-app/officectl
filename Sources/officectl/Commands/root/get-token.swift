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
	let googleConfig = try context.container.make(OfficeKitConfig.self).googleConfigOrThrow()
	
	let scopes = try nil2throw(f.getString(name: "scopes"), "scopes")
	
	let googleConnector = try GoogleJWTConnector(key: googleConfig.connectorSettings)
	let f = googleConnector.connect(scope: Set(scopes.components(separatedBy: ",")), asyncConfig: asyncConfig)
	.then{ _ -> Future<Void> in
		print(googleConnector.token!)
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
	return f
}
