/*
 * ApiUsers+Conveniences.swift
 * officectl
 *
 * Created by François Lamboley on 2022/01/13.
 */

import Foundation

import Vapor

import OfficeKit
import OfficeModel



extension ApiUsers {
	
	init(users: [MultiServicesUser], fetchErrorsByServices: [AnyUserDirectoryService: Error], orderedServices: [AnyUserDirectoryService], environment: Environment) throws {
		try self.init(
			results: Dictionary(uniqueKeysWithValues: orderedServices.map{ service in (service.config.serviceID, ApiResult(result: fetchErrorsByServices[service].flatMap{ Result.failure($0) } ?? Result.success(None()), environment: environment)) }),
			mergedResults: users.map{ try ApiMergedUserWithSource(multiUsers: $0, orderedServices: orderedServices) }.sorted{ ($0.lastName ?? "").localizedCompare($1.lastName ?? "") != .orderedDescending }
		)
	}
	
}
