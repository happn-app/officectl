/*
 * server.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import ArgumentParser
import JWT
import Vapor

import OfficeServer



struct Server : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Interact with the server.",
		subcommands: [
			ProcessQueues.self,
			ProcessScheduledQueues.self,
			Routes.self,
			Serve.self
		]
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	
	
	static func runVaporCommand(_ args: [String], officectlOptions: Officectl.Options) throws {
		/* We require the server conf for any server command. */
		guard let serverConf = officectlOptions.conf?.serverConf else {
			/* An alternative to printing a message via the logger then throwing the ExitCode.validationFailure error would be to throw a ValidationError directly.
			 * ValidationError takes care of printing the message to stderr, but it will also print the usage after the message.
			 * That’s why we decided against that option and printed the message ourselves. */
			officectlOptions.logger.error("Server’s conf is required when running a server command.")
			throw ExitCode.validationFailure
		}
		
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
		
		if let dir = officectlOptions.resolvedStaticDataDir {
			app.directory = DirectoryConfiguration(workingDirectory: dir.lexicallyNormalized().string + "/"/* FilePath always removes the trailing / if any. */)
		}
		app.jwtKey = serverConf.mainJWTKey
		for (key, secret) in serverConf.jwtSecrets {
			app.jwt.signers.use(.hs256(key: secret), kid: JWKIdentifier(string: key))
		}
		app.officeKitServices = officectlOptions.officeKitServices
		
		try configure(app)
		try app.run()
	}
	
}
