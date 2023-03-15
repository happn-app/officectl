/*
 * list.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/17.
 */

import Foundation
#if canImport(TabularData)
import TabularData
#endif

import ArgumentParser

import OfficeKit



struct List : AsyncParsableCommand {
	
	enum Format : String, CaseIterable, ExpressibleByArgument {
		
		case csv
		case json
		case text
		
	}
	
	static var configuration = CommandConfiguration(
		abstract: "Create a user."
	)
	
	@OptionGroup()
	var officectlOptions: Officectl.Options
	@OptionGroup()
	var usersOptions: Users.Options
	
	@Flag(help: "For the directory services that supports it, do we filter out the suspended users?")
	var includeSuspendedUsers = false
	
	@Option(name: .shortAndLong, help: "The format to use to output the results of the list.")
	var format: Format = .text
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.officeKitServices
		
		let multiUsersResult = try await MultiServicesUser.fetchAll(in: officeKitServices.hashableUserServices(matching: usersOptions.serviceIDs), includeSuspended: includeSuspendedUsers)
#if canImport(TabularData)
		/* TabularData knows how to export in CSV, text or JSON, but only on macOS 13 for the JSON part. */
		switch format {
			case .csv:                              return try FileHandle.standardOutput.write(contentsOf:      multiUsersAsDataFrame(multiUsersResult.users).csvRepresentation())
			case .text:                             return try FileHandle.standardOutput.write(contentsOf: Data(multiUsersAsDataFrame(multiUsersResult.users).description(options: .init(maximumLineWidth: .max, maximumCellWidth: .max, maximumRowCount: .max, includesColumnTypes: false)).utf8))
			case .json: if #available(macOS 13, *) {return try FileHandle.standardOutput.write(contentsOf:      multiUsersAsDataFrame(multiUsersResult.users).jsonRepresentation())}
		}
#endif
		multiUsersResult.users.forEach{ multiUser in
			print("---")
			let maxLength = multiUser.keys.map(\.value.id.rawValue.count).max() ?? 0
			for key in (multiUser.keys.sorted{ $0.value.id.rawValue < $1.value.id.rawValue }) {
				print("\(String(repeating: " ", count: maxLength - key.value.id.rawValue.count))\(key.id): ", terminator: "")
				let result = multiUser[key]!
				switch result {
					case .success(nil):       print("<none>")
					case .success(let user?): print("\(UserAndServiceFrom(user: user, service: key.value)!.taggedID.id)")
					case .failure(let error): print("ERROR \(error)")
				}
			}
		}
	}
	
#if canImport(TabularData)
	private func multiUsersAsDataFrame(_ multiUsers: [MultiServicesUser]) -> DataFrame {
		let allServices = Set(multiUsers.flatMap{ $0.keys }).sorted{ $0.value.id.rawValue < $1.value.id.rawValue }
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
			dataFrame.append(column: Column<String>(name: service.value.id.rawValue, contents: rows))
		}
		return dataFrame
	}
#endif
	
}
