/*
 * users.swift
 * officectl
 *
 * Created by François Lamboley on 20/08/2018.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit



struct UserCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "user",
		abstract: "Interact with the users",
		subcommands: [
		]
	)
	
	@OptionGroup()
	var globalOptions: GlobalOptions
	
}
