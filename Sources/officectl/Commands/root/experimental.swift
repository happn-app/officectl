/*
 * experimental.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation

import ArgumentParser



struct ExperimentalCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "experimental",
		abstract: "Experimental commands",
		shouldDisplay: false,
		subcommands: [
			CurrentDevTestCommand.self,
			ConsolepermCommand.self,
			FindInDrivesCommand.self,
			ListLicensesCommand.self
		]
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
}
