/*
 * serve.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import ArgumentParser



struct Serve : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Start the server."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		
		var serverArgs = [String]()
		if let hostname = officectlOptions.conf?.serverConf?.hostname {
			serverArgs.append(contentsOf: ["--hostname", hostname])
		}
		if let port = officectlOptions.conf?.serverConf?.port {
			serverArgs.append(contentsOf: ["--port", String(port)])
		}
		try Server.runVaporCommand(["serve"] + serverArgs, officectlOptions: officectlOptions)
	}
	
}
