/*
 * server.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeServer



struct Server : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Interact with the server.",
		subcommands: [
			Routes.self,
			Serve.self
		]
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	static func runVaporCommand(_ args: [String], officectlOptions: Officectl.Options) throws {
		/* Straight from Vapor’s `bootstrap(from:_:)` */
		if officectlOptions.resolvedLogLevel > .trace {
			StackTrace.isCaptureEnabled = false
		}
		
		var vaporEnv: Vapor.Environment
		switch officectlOptions.resolvedEnvironment {
			case .production:  vaporEnv = .production
			case .development: vaporEnv = .development
		}
		
		vaporEnv.commandInput = CommandInput(arguments: ["office-server"/* Could be anything, it’s a fake argv[0] */] + args)
		let app = Application(vaporEnv)
		defer {app.shutdown()} /* Apparently it’s ok to shutdown the app before it’s run (case where configure fails). */
		
		try configure(app)
		try app.run()
	}
	
}
