/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser
import Vapor

import OfficeKit
import SemiSingleton
import URLRequestOperation



struct ListLicensesCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "list-licenses",
		abstract: "List all licenses in SimpleMDM",
		shouldDisplay: false
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		let officectlConfig = app.officectlConfig
		let semiSingletonStore = app.semiSingletonStore
		let simpleMDMToken = try nil2throw(officectlConfig.tmpSimpleMDMToken)
		
		/* Get all licenses in SimpleMDM */
		let getDevicesAction: GetMDMDevicesWithAttributesAction = semiSingletonStore.semiSingleton(forKey: simpleMDMToken)
		try await getDevicesAction.start(parameters: (), weakeningMode: .always(successDelay: 3600, errorDelay: nil), shouldJoinRunningAction: { _ in true }, shouldRetrievePreviousRun: { _, wasSuccessful in wasSuccessful })
			.compactMap{ deviceAndAttributes -> String? in
				guard
					let licensesStr = deviceAndAttributes.1["software_licenses"]?
						.splitLines()
						.map({ $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) })
						.filter({ !$0.isEmpty }),
					!licensesStr.isEmpty
				else {return nil}
				
				var line = "\(deviceAndAttributes.0.attributes.name):"
				
				let jsonDecoder = JSONDecoder()
				licensesStr.forEach{ licenseStr in
					guard let license = try? jsonDecoder.decode(Dictionary<String, String>.self, from: Data(licenseStr.utf8)) else {
						app.logger.warning("Found invalid license (cannot decode as [String: String]) stored in device \(deviceAndAttributes.0.id)")
						return
					}
					line += " \(license[" name"] ?? "<unnamed>")"
				}
				return line
			}
			.sorted()
			.forEach{ print($0) }
	}
	
}


private extension String {
	
	func splitLines() -> [String] {
		var res = [String]()
		enumerateLines{ line, _ in res.append(line) }
		return res
	}
	
}
