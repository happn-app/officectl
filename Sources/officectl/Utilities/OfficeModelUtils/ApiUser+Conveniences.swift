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



extension ApiUser {
	
	init(user: MultiServicesUser, orderedServices: [AnyUserDirectoryService], environment: Environment) throws {
		let directoryUserResultsByServiceID: [String: Result<ApiDirectoryUser?, Error>] = user.errorsAndItemsByServiceID.mapValues{ result in
			result.flatMap{ optionalUser in Result{ try optionalUser.flatMap{ try ApiDirectoryUser(user: $0) } } }
		}
		self.init(
			results: directoryUserResultsByServiceID.mapValues{ ApiResult(result: $0, environment: environment) },
			mergedResults: try ApiMergedUser(multiUsers: user, orderedServices: orderedServices)
		)
	}
	
}
