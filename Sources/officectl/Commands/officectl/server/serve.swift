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
		
		try Server.runVaporCommand(["serve"], officectlOptions: officectlOptions)
	}
	
}
