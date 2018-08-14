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



func serverServe(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let hostname = f.getString(name: "hostname")!
	let port = f.getInt(name: "port")!
	
	var context = context
	context.options["port"] = String(port)
	context.options["hostname"] = hostname
	return try ServeCommand(server: context.container.make()).run(using: context)
}
