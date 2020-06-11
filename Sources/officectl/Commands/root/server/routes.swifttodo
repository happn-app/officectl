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



func serverRoutes(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let app = context.application
	let eventLoop = try app.services.make(EventLoop.self)
	
	guard let routesCommand = app.commands.commands["routes"] else {
		throw "Cannot find the routes command"
	}
	
	var context = context
	try routesCommand.run(using: &context)
	return eventLoop.makeSucceededFuture(())
}
