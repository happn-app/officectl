/*
 * server.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser



struct ServerCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "server",
		abstract: "Server-related commands.",
		subcommands: [
			ServerServeCommand.self,
			ServerRoutesCommand.self
		]
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
}
