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
import OfficeModel



struct List : AsyncParsableCommand {
	
	enum Format : String, CaseIterable, ExpressibleByArgument {
		
		case text
		case json
		
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
		
		let services = officeKitServices.hashableUserServices(matching: usersOptions.serviceIDs)
		let multiUsersResult = try await MultiServicesUser.fetchAll(in: services, includeSuspended: includeSuspendedUsers)
		switch format {
			case .text:     printUsersAsText(multiUsersResult)
			case .json: try printUsersAsJSON(multiUsersResult, sourceServices: services)
		}
	}
	
	private func printUsersAsText(_ fetchResult: (users: [MultiServicesUser], fetchErrorsByServices: [HashableUserService: Error])) {
#if !canImport(TabularData)
		multiUsers.users.forEach{ multiUser in
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
#else
		let multiUsers = fetchResult.users
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
		print(dataFrame.sorted(on: "ggl").description(options: .init(maximumLineWidth: .max, maximumCellWidth: .max, maximumRowCount: .max, includesColumnTypes: false)))
#endif
	}
	
	private func printUsersAsJSON(_ multiUsers: (users: [MultiServicesUser], fetchErrorsByServices: [HashableUserService: Error]), sourceServices: Set<HashableUserService>) throws {
		let (users, fetchErrors) = multiUsers
		let errors: [Tag: Result<None, ApiError>] = Dictionary(uniqueKeysWithValues: sourceServices.map{ service in
			(service.value.id, fetchErrors[service].flatMap{ .failure(ApiError(error: $0)) } ?? .success(None()))
		})
		let res = ApiUsers(
			mergedResults: users.map{ ApiUser(multiServicesUser: $0, servicesMergePriority: [], logger: officectlOptions.logger) },
			results: errors
		)
		try FileHandle.standardOutput.write(contentsOf: JSONEncoder().encode(res))
	}
	
}
