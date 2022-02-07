/*
 * users.swift
 * officectl
 *
 * Created by François Lamboley on 20/08/2018.
 */

import Foundation

import ArgumentParser



struct UserCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "users",
		abstract: "Interact with the users",
		subcommands: [
			UserCreateCommand.self,
			UserDeleteCommand.self,
			UserListCommand.self,
			UserChangePasswordCommand.self
		]
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
}
