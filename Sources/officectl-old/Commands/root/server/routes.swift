/*
 * routes.swift
 * officectl
 *
 * Created by François Lamboley on 2018/07/26.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit



struct ServerRoutesCommand : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "routes",
		abstract: "Show the routes supported by the server."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() async throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: setup_routes_and_middlewares, vaporRun)
	}
	
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		guard let routesCommand = app.commands.commands["routes"] else {
			throw "Cannot find the routes command"
		}
		
		var context = context
		try routesCommand.run(using: &context)
	}
	
}