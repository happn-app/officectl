/*
 * routes.swift
 * officectl
 *
 * Created by François Lamboley on 26/07/2018.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit



struct ServerRoutesCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "routes",
		abstract: "Show the routes supported by the server."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	func vaporRun(_ context: CommandContext) throws -> EventLoopFuture<Void> {
		let app = context.application
		let eventLoop = try app.services.make(EventLoop.self)
		
		guard let routesCommand = app.commands.commands["routes"] else {
			throw "Cannot find the routes command"
		}
		
		var context = context
		try routesCommand.run(using: &context)
		return eventLoop.makeSucceededFuture(())
	}
	
}
