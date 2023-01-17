/*
 * create.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser

import OfficeKit



struct Create : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Create a user."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	@OptionGroup()
	var usersOptions: Users.Options
	@OptionGroup()
	var userPropertiesOptions: Users.UserPropertiesOptions
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.resolvedOfficeKitServices
		
		let multiUsers = try await MultiServicesUser.fetchAll(in: Set(officeKitServices.userServices.map(HashableUserService.init)), using: Officectl.services)
		multiUsers.users.forEach{ print($0) }
//		for userService in officeKitServices.userServices {
//			print("****************************")
//			print("\(userService.id)")
//			try await print(userService.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: Officectl.services))
//		}
	}
	
}
