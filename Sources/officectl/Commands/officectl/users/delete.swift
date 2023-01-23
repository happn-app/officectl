/*
 * delete.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/23.
 */

import Foundation

import ArgumentParser

import OfficeKit



struct Delete : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Delete a user."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	@OptionGroup()
	var usersOptions: Users.Options
	@OptionGroup()
	var serviceSearchSelectionOptions: Officectl.ServiceSearchSelectionOptions
	
	@Argument
	var anyUserID: String
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let servicesActedOn = officectlOptions.officeKitServices.hashableUserServices(matching: usersOptions.serviceIDs)
		let servicesForUserSearch = officectlOptions.officeKitServices.hashableUserServices(matching: serviceSearchSelectionOptions.idSearchServices)
		
		guard !servicesActedOn.isEmpty else {
			officectlOptions.logger.info("No services match; nothing to do.")
			return
		}
		
		guard let userAndService = await UserAndServiceFrom(stringUserID: anyUserID, fromAny: servicesForUserSearch, propertiesToFetch: nil, depServices: Officectl.services) else {
			officectlOptions.logger.error("User cannot be found.")
			throw ExitCode(rawValue: 1)
		}
		
		print(userAndService)
//		MultiServicesUser.fe
	}
	
}
