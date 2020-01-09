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
	let eventLoop = try app.services.make(EventLoop.self)
	
	var context = context
	try app.commands.commands["routes"]?.run(using: &context)
	return eventLoop.makeSucceededFuture(())
}
