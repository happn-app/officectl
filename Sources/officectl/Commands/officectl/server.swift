/*
 * server.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import ArgumentParser



struct Server : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Interact with the server.",
		subcommands: [
			Serve.self
		]
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
}
