/*
 * users.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser



struct Users : AsyncParsableCommand {

	static var configuration = CommandConfiguration(
		abstract: "Manage the users.",
		subcommands: [
			Create.self
		]
	)

}
