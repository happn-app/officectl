/*
 * server--process-jobs.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import ArgumentParser

import OfficeServer



struct Server_ProcessJobs : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "process-jobs",
		abstract: "Start processing (non-scheduled) jobs in Vapor queues."
	)
	
	struct Options : ParsableArguments {
		
		/* Officially from Vapor the queue option is available for both scheduled and non-scheduled queues, but in practice --queue does nothing for scheduled queues. */
		@ArgumentParser.Option(name: .shortAndLong, help: "The queue to process.")
		var queue: String?
		
	}
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	@OptionGroup()
	var queuesOptions: Options
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		
		try Server.runVaporCommand(["queues"] + (queuesOptions.queue.flatMap{ ["--queue", $0] } ?? []), officectlOptions: officectlOptions, appSetup: OfficeServerConfig.setupQueues)
	}
	
}
