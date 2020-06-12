/*
 * delete.swift
 * officectl
 *
 * Created by François Lamboley on 20/08/2018.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit



struct UserDeleteCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "delete",
		abstract: "Delete a user."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	func vaporRun(_ context: CommandContext) throws -> EventLoopFuture<Void> {
		throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "not implemented"])
	}
	
}
