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
	
	try app.server.start(hostname: config.serverHost, port: config.serverPort)
	return app.server.onShutdown.hop(to: eventLoop)
}
