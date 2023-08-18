/*
 * services--list.swift
 * officectl
 *
 * Created by François Lamboley on 2023/08/18.
 */

import Foundation

import ArgumentParser



struct Services_List : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "list",
		abstract: "List the services officectl knows about (from its configuration file)."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	@Option(name: .customLong("exclude-service-ids"), help: "The comma-separated list of service IDs to exclude from the list.")
	var excludedServiceIDs: String?
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		
		let excludedServiceIDs = excludedServiceIDs?.split(separator: ",").map(String.init)
		let officeKitServices = officectlOptions.officeKitServices
		
		print(officeKitServices.allServices
			.filter({ !(excludedServiceIDs?.contains($0.key.rawValue) ?? false) })
			.keys
			.map(\.rawValue)
			.joined(separator: ","))
	}
	
}
