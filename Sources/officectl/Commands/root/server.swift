/*
 * server.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation

import ArgumentParser



struct ServerCommand : AsyncParsableCommand {
	
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
