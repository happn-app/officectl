/*
 * services.swift
 * officectl
 *
 * Created by François Lamboley on 2023/08/18.
 */

import Foundation

import ArgumentParser



struct Services : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Interact with services directly.",
		subcommands: [
			Services_List.self
		]
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
}
