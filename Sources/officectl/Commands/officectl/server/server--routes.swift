/*
 * server--routes.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import ArgumentParser

import OfficeServer



struct Server_Routes : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "routes",
		abstract: "Show all the server’s routes."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		
		try Server.runVaporCommand(["routes"], officectlOptions: officectlOptions, appSetup: OfficeServerConfig.setupRoutes)
	}
	
}
