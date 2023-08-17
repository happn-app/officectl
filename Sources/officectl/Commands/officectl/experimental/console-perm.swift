/*
 * console-perm.swift
 * officectl
 *
 * Created by François Lamboley on 2023/08/17.
 */

import Foundation

import ArgumentParser
import Email
import FormURLEncodedCoder
import UnwrapOrThrow
import URLRequestOperation

import HappnOffice
import OfficeKit



struct ConsolePerm : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Set the console permissions for a given user in the happn console."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	
	@Argument
	var email: Email
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.officeKitServices
		
		guard let happnService = officeKitServices.hashableUserServices(matching: "hppn").onlyElement?.value as? HappnService else {
			officectlOptions.logger.critical("happn service not found; bailing.")
			throw ExitCode(1)
		}
		
		officectlOptions.logger.critical("Not implemented")
		throw ExitCode(1)
	}
	
}
