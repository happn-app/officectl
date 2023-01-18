/*
 * create.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation
#if canImport(TabularData)
import TabularData
#endif

import ArgumentParser

import OfficeKit
import LDAPOffice



struct List : AsyncParsableCommand {
	
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
		let officeKitServices = officectlOptions.officeKitServices
		
		let multiUsersResult = try await MultiServicesUser.fetchAll(in: officeKitServices.hashableUserServices(matching: usersOptions.serviceIDs), using: Officectl.services)
#if !canImport(TabularData)
		multiUsersResult.users.forEach{ multiUser in
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
#else
		let multiUsers = multiUsersResult.users
		let allServices = Set(multiUsers.flatMap{ $0.keys }).sorted{ $0.value.id < $1.value.id }
		var dataFrame = DataFrame()
		allServices.forEach{ service in
			let rows = multiUsers.map{ $0[service] }.map{ userResult in
				guard let userResult else {
					return "<internal error>"
				}
				switch userResult {
					case .success(nil):       return "<none>"
					case .success(let user?): return "\(UserAndServiceFrom(user: user, service: service.value)!.taggedID.id)"
					case .failure:            return "ERROR"
				}
			}
			dataFrame.append(column: Column<String>(name: service.value.id, contents: rows))
		}
		print(dataFrame.sorted(on: "ggl").description(options: .init(maximumLineWidth: .max, maximumCellWidth: .max, maximumRowCount: .max, includesColumnTypes: false)))
#endif
	}
	
}
