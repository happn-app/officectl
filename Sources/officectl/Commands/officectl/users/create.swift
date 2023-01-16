/*
 * create.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser



struct Create : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Create a user."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	@OptionGroup()
	var usersOptions: Users.Options
	@OptionGroup()
	var userPropertiesOptions: Users.UserPropertiesOptions
	
	func run() async throws {
		officectlOptions.bootstrap()
		
		officectlOptions.logger.warning("Hello from users create")
		print(userPropertiesOptions)
	}
	
}
