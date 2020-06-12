/*
 * devtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser



struct DevtestCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "devtest",
		abstract: "Developer tests commands",
		shouldDisplay: false,
		subcommands: [
			CurrentDevTestCommand.self,
			ConsolepermCommand.self
		]
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
}
