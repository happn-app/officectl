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
	let eventLoop = app.eventLoopGroup.next()
	let config = app.officectlConfig
	
	var input = CommandInput(arguments: ["fake vapor", "--port", String(config.serverPort), "--hostname", config.serverHost])
	let signature = try ServeCommand.Signature(from: &input)
	
	try app.server.command.run(using: context, signature: signature)
	return eventLoop.makeSucceededFuture(())
}
