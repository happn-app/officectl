/*
 * serve.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import ArgumentParser
import Vapor



struct Serve : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Start the server."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	func run() async throws {
		try officectlOptions.bootstrap()
		
		/* Straight from Vapor’s `bootstrap(from:_:)` */
		if officectlOptions.resolvedLogLevel > .trace {
			StackTrace.isCaptureEnabled = false
		}
		
		var vaporEnv: Vapor.Environment
		switch officectlOptions.resolvedEnvironment {
			case .production:  vaporEnv = .production
			case .development: vaporEnv = .development
		}
		
		vaporEnv.commandInput = CommandInput(arguments: ["serve"])
		let app = Application(vaporEnv)
		defer {app.shutdown()}
		try app.run()
	}
	
}
