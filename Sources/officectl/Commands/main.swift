/*
 * root.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser



struct OfficectlRootCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "officectl",
		abstract: "Manage multiple directories.",
		subcommands: [
			SyncCommand.self,
			
			UserCommand.self
		]
	)
	
	@OptionGroup()
	var globalOptions: GlobalOptions
	
}

OfficectlRootCommand.main()
