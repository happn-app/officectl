/*
 * experimental.swift
 * officectl
 *
 * Created by François Lamboley on 2023/08/17.
 */

import Foundation

import ArgumentParser
import JWT



struct Experimental : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Experimental commands; use with care.",
		shouldDisplay: false,
		subcommands: [
			ConsolePerm.self
		]
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
}
