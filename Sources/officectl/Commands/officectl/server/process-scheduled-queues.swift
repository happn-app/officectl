/*
 * process-queues.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import ArgumentParser



struct ProcessScheduledQueues : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Start processing scheduled jobs in Vapor queues."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		
		try Server.runVaporCommand(["queues", "--scheduled"], officectlOptions: officectlOptions)
	}
	
}
