/*
 * HappnUser+Get.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/18.
 */

import Foundation

import Email
import URLRequestOperation

import OfficeKit



internal extension HappnUser {
	
	/**
	 Search for the users matching the given text (if text is `nil`, all the users are retrieved).
	 
	 Note: The only way to find a user by his login on happn’s API is to do a full-text search on all fields and filter later. */
	static func get(id: String, propertiesToFetch keys: Set<HappnUser.CodingKeys>, connector: HappnConnector) async throws -> HappnUser? {
		let op = try URLRequestDataOperation<ApiResult<HappnUser>>.forAPIRequest(
			url: connector.baseURL.appending("api", "users", id), urlParameters: ["fields": Self.validFieldsParameter(from: keys)],
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		let res = try await op.startAndGetResult().result
		guard res.success, let user = res.data else {
			throw Err.apiError(code: res.errorCode, message: res.error ?? "Unknown API error fetching the user.")
		}
		return user
	}
	
}
