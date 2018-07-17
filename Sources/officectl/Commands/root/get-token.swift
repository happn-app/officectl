/*
 * get-token.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import NIO

import OfficeKit



func getToken(flags f: Flags, arguments args: [String], asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
	do {
		let scopes = f.getString(name: "scopes")!
		let userBehalf = f.getString(name: "google-admin-email")!
		let googleConnector = try GoogleJWTConnector(flags: f, userBehalf: userBehalf)
		
		let f = googleConnector.connect(scope: Set(scopes.components(separatedBy: ",")), asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<Void> in
			print(googleConnector.token!)
			return asyncConfig.eventLoop.newSucceededFuture(result: ())
		}
		return f
	} catch {
		return asyncConfig.eventLoop.newFailedFuture(error: error)
	}
}
