/*
 * serve.swift
 * officectl
 *
 * Created by François Lamboley on 26/07/2018.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func serverServe(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let config = app.officectlConfig
	let eventLoop = try app.services.make(EventLoop.self)
	
	var context = context
	context.input = CommandInput(arguments: ["fake vapor", "--port", String(config.serverPort), "--hostname", config.serverHost])
	
	try app.commands.commands["serve"]?.run(using: &context)
	return eventLoop.makeSucceededFuture(())
}
