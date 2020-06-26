/*
 * find-in-drives.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2020.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit
import SemiSingleton
import URLRequestOperation



struct FindInDrivesCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "find-in-drives",
		abstract: "Find the given file or folder in all users drives."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) throws -> EventLoopFuture<Void> {
		let app = context.application
		let sProvider = app.officeKitServiceProvider
		let eventLoop = try app.services.make(EventLoop.self)
		
		let services = try sProvider.getAllServices()
		print(services)
		
		return eventLoop.future()
	}
	
}
