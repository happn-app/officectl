/*
 * HappnUser+Search.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/18.
 */

import Foundation

import Email
import OfficeKit2
import URLRequestOperation



internal extension HappnUser {
	
	/**
	 Search for the users matching the given text (if text is `nil`, all the users are retrieved).
	 
	 Note: The only way to find a user by his login on happn’s API is to do a full-text search on all fields and filter later. */
	static func get(id: String, propertiesToFetch fields: Set<HappnUser.CodingKeys>, connector: HappnConnector) async throws -> HappnUser? {
		let op = try URLRequestDataOperation<ApiResult<HappnUser>>.forAPIRequest(
			url: connector.baseURL.appending("api", "users", id), urlParameters: ["fields": Set(fields + [.login, .id, .type]).map{ $0.stringValue }.joined(separator: ",")],
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		let res = try await op.startAndGetResult().result
		guard res.success, let user = res.data else {
			throw Err.apiError
		}
		return user
	}
	
}
