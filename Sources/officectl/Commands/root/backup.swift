/*
 * backup.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser



struct BackupCommand : ParsableCommand {
	
	struct Options : ParsableArguments {
		
		@Option(help: "The enclosing folder destination for the backup.")
		var downloadsDestinationFolder: String
		
	}
	
	static var configuration = CommandConfiguration(
		commandName: "backup",
		abstract: "Backup informations from servies (drive, mails, etc.)",
		subcommands: [
			BackupGitHubCommand.self,
			BackupDriveCommand.self,
			BackupMailsCommand.self
		]
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@OptionGroup()
	var backupOptions: Options
	
}
