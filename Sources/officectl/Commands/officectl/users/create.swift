/*
 * create.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser

import OfficeKit
import LDAPOffice



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
		
//		let ldapUsers = try await officeKitServices.userServices.compactMap{ $0 as? LDAPService }.first?.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: Officectl.services)
//		ldapUsers?.forEach{ print($0.id) }
		let multiUsers = try await MultiServicesUser.fetchAll(in: Set(officeKitServices.userServices.map(HashableUserService.init)), using: Officectl.services)
		multiUsers.users.forEach{ multiUser in
			print("---")
			let maxLength = multiUser.keys.map(\.value.id.count).max() ?? 0
			for key in (multiUser.keys.sorted{ $0.value.id < $1.value.id }) {
				print("\(String(repeating: " ", count: maxLength - key.value.id.count))\(key.id): ", terminator: "")
				let result = multiUser[key]!
				switch result {
					case .success(nil):       print("<none>")
					case .success(let user?): print("\(UserAndServiceFrom(user: user, service: key.value)!.taggedID.id)")
					case .failure(let error): print("ERROR \(error)")
				}
			}
		}
	}
	
}
