/*
 * users--create.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser

import OfficeKit



struct Users_Create : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "create",
		abstract: "Create a user."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	@OptionGroup()
	var usersOptions: Users.Options
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.officeKitServices
		
	}
	
}
