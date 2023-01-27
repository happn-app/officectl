/*
 * serve.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import ArgumentParser

import OfficeServer



struct Serve : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Start the server."
	)
	
	struct Options : ParsableArguments {
		
		/* Note: We do **not** provide the bind option because I don’t like it
		 *  (because of IPv6; Vapor simply ignores there are hostname that can contain semicolons;
		 *   I don’t want to ignore that but also want to be as compatible as possible with Vapor’s options,
		 *   so the best solution is to simply not provide the bind option).
		 * Also, not providing the bind option simplifies the hostname and port selection! */
		
		@Option(name: [.customShort("H"), .long], help: "The hostname the server will run on. Defaults to localhost.")
		var hostname: String?
		
		@Option(name: .shortAndLong, help: "The port the server will run on. Defaults to 8080.")
		var port: Int?
		
	}
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	@OptionGroup()
	var options: Options
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		
		var serverArgs = [String]()
		if let hostname = options.hostname ?? officectlOptions.conf?.serverConf?.hostname {
			serverArgs.append(contentsOf: ["--hostname", hostname])
		}
		if let port = options.port ?? officectlOptions.conf?.serverConf?.port {
			serverArgs.append(contentsOf: ["--port", String(port)])
		}
		try Server.runVaporCommand(["serve"] + serverArgs, officectlOptions: officectlOptions, appSetup: { app in
			try OfficeServerConfig.setupServer(app, scheduledJobs: [
				(UpdateCAMetricsJob(), { $0.daily().at(4, 30) })
			])
		})
	}
	
}
