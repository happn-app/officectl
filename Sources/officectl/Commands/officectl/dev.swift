/*
 * dev.swift
 * officectl
 *
 * Created by François Lamboley on 2023/08/11.
 */

import Foundation

import ArgumentParser



struct Dev : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Dev commands; use with care, only if you know what you’re doing.",
		shouldDisplay: false,
		subcommands: [
			Dev_CurTest.self
		]
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
}
