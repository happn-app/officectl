/*
 * users.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser
import Email



struct Users : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Manage the users.",
		subcommands: [
			Create.self,
			List.self
		]
	)
	
	struct Options : ParsableArguments {
		
		@Option(name: .customLong("service-ids"), help: "The list of service IDs on which the command will act.")
		var serviceIDs: String?
		
	}
	
	struct UserPropertiesOptions : ParsableArguments {
		
		@Option(name: .long, help: "The first name of the user.")
		var firstName: String?
		
		@Option(name: .long, help: "The last name of the user.")
		var lastName: String?
		
		@Option(name: .long, help: "The email of the user.")
		var email: Email?
		
		@Option(name: .customLong("custom-property"), help: "A list of custom properties for the user.")
		var customProperties: [String] = []
		
	}
	
	@OptionGroup()
	var options: Options
	
}
