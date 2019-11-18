/*
 * routes.swift
 * officectl
 *
 * Created by François Lamboley on 26/07/2018.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func serverRoutes(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let eventLoop = app.make(EventLoop.self)
	
	var context = context
	try RoutesCommand(routes: app.make()).run(using: &context)
	return eventLoop.makeSucceededFuture(())
}
