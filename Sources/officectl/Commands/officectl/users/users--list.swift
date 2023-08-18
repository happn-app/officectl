/*
 * users--list.swift
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



struct Users_List : AsyncParsableCommand {
	
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
	
	@Flag(help: "Set this to ignore the “ignored users by services” entry in the configuration.")
	var includeIgnoredUsers = false
	
	@Option(name: .shortAndLong, help: "The format to use to output the results of the list.")
	var format: Format = .text
	
	
	func run() async throws {
		try officectlOptions.bootstrap()
		let officeKitServices = officectlOptions.officeKitServices
		
		let multiUsersResult = try await MultiServicesUser.fetchAll(
			in: officeKitServices.hashableUserServices(matching: usersOptions.serviceIDs),
			includeSuspended: includeSuspendedUsers,
			customFetchFilter: { userAndService in
				guard !includeIgnoredUsers else {
					return true
				}
				let ignoredUsers = officectlOptions.ignoredUsersByServices[userAndService.serviceID] ?? []
				return !ignoredUsers.contains(userAndService.taggedID.id)
			}
		)
		for (service, error) in multiUsersResult.fetchErrorsByServices {
			officectlOptions.logger.warning("Failed fetching users.", metadata: [LMK.serviceID: "\(service)", LMK.error: "\(error)"])
		}
#if canImport(TabularData)
		/* TabularData knows how to export in CSV, text or JSON, but only on macOS 13 for the JSON part. */
		switch format {
			case .csv:                              return try FileHandle.standardOutput.write(contentsOf:      multiUsersAsDataFrame(multiUsersResult.users).csvRepresentation())
			case .text:                             return try FileHandle.standardOutput.write(contentsOf: Data(multiUsersAsDataFrame(multiUsersResult.users).description(options: .init(maximumLineWidth: .max, maximumCellWidth: .max, maximumRowCount: .max, includesColumnTypes: false)).utf8))
			case .json: if #available(macOS 13, *) {return try FileHandle.standardOutput.write(contentsOf:      multiUsersAsDataFrame(multiUsersResult.users).jsonRepresentation())}
		}
#endif
		let tabData = multiUsersAsTabularData(multiUsersResult.users)
		switch format {
			case .json: try FileHandle.standardOutput.write(contentsOf: JSONEncoder().encode(tabData.values))
			case .text:
				let maxLength = tabData.keys.map(\.count).max() ?? 0
				tabData.values.forEach{ userTabData in
					print("---")
					for key in tabData.keys {
						print("\(String(repeating: " ", count: maxLength - key.count))\(key): \(userTabData[key]!)")
					}
				}
			case .csv:
				print(tabData.keys.map(Self.csvString(from:)).joined(separator: ","))
				tabData.values.forEach{ userTabData in
					print(tabData.keys.map{ Self.csvString(from: userTabData[$0]!) }.joined(separator: ","))
				}
		}
	}
	
	private static func csvString(from str: String) -> String {
		let sep = ","
		/* From LocMapper. */
		guard sep.utf16.count == 1, sep != "\"", sep != "\n", sep != "\r" else {fatalError("Cannot use “\(sep)” as a CSV separator")}
		/* We use the large “newlines” character set instead of simply \n and \r to solve some problems when solving merge conflicts with FileMerge.
		 * (FileMerge sees a weird UTF-8 newline and proposes to solve the problem by converting the newlines in the file to CR, LF or CRLF.
		 *  When it does that, a field containing such a character becomes incomplete and the line stops there.) */
		if str.rangeOfCharacter(from: CharacterSet(charactersIn: "\(sep)\"").union(.newlines)) != nil {
			/* Double quotes needed */
			let doubledDoubleQuotes = str.replacingOccurrences(of: "\"", with: "\"\"")
			return "\"\(doubledDoubleQuotes)\""
		} else {
			/* Double quotes not needed */
			return str
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
	
	/* Duplicated in OfficeServer. */
	private func multiUsersAsTabularData(_ multiUsers: [MultiServicesUser]) -> (keys: [String], values: [[String: String]]) {
		let allServices = Set(multiUsers.flatMap{ $0.keys }).sorted{ $0.value.id.rawValue < $1.value.id.rawValue }
		let values = multiUsers.map{ multiUser in
			return Dictionary(uniqueKeysWithValues: allServices.map{ service in
				let userStr: String
				switch multiUser[service] {
					case .none:               userStr = "<internal error>"
					case .success(nil)?:      userStr = "<none>"
					case .success(let user?): userStr = "\(UserAndServiceFrom(user: user, service: service.value)!.taggedID.id)"
					case .failure:            userStr = "ERROR"
				}
				return (service.value.id.rawValue, userStr)
			})
		}
		return (keys: allServices.map{ $0.value.id.rawValue }, values: values)
	}
	
}
