/*
 * HappnUser+Search.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/18.
 */

import Foundation

import Email
import URLRequestOperation

import OfficeKit2



internal extension HappnUser {
	
	/**
	 Search for the users matching the given text (if text is `nil`, all the users are retrieved).
	 
	 Note: The only way to find a user by his login on happn’s API is to do a full-text search on all fields and filter later. */
	static func search(text: String?, admins: Bool = true, propertiesToFetch: Set<HappnUser.CodingKeys>, connector: HappnConnector) async throws -> [HappnUser] {
		/* Key is the user ID. */
		var res = [Email: HappnUser]()
		
		let limit = 500
		var curOffset = 0
		var nUsersAtCurPage = 0
		repeat {
			let usersAtPage = try await searchResults(
				for: SearchRequest(offset: curOffset, limit: limit, isAdmin: admins, fullTextSearchWithAllTerms: text),
				fields: propertiesToFetch,
				connector: connector
			)
			nUsersAtCurPage = usersAtPage.count
			usersAtPage.forEach{ res[$0.login] = $0 }
			curOffset += limit
		} while nUsersAtCurPage >= limit/2
		
		/* Get users from IDs search. Searches for specific _persistent_ ids; this is not what we want. */
//		if let text {
//			curOffset = 0
//			repeat {
//				let usersAtPage = try await searchResults(
//					for: SearchRequest(offset: curOffset, limit: limit, isAdmin: admins, ids: [text]),
//					fields: propertiesToFetch,
//					connector: connector
//				)
//				nUsersAtCurPage = usersAtPage.count
//				usersAtPage.forEach{ res[$0.login] = $0 }
//				curOffset += limit
//			} while nUsersAtCurPage >= limit/2
//		}
		
		return Array(res.values)
	}
	
	private static func searchResults(for request: SearchRequest, fields: Set<HappnUser.CodingKeys>, connector: HappnConnector) async throws -> [HappnUser] {
		let res = try await URLRequestDataOperation<ApiResult<[HappnUser]>>.forAPIRequest(
			url: connector.baseURL.appending("api", "v1", "users-search"),
			urlParameters: ["fields": Set(fields + [.login, .id, .type]).map{ $0.stringValue }.joined(separator: ",")],
			httpBody: request,
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		).startAndGetResult().result
		guard res.success, let users = res.data else {
			throw Err.apiError(code: res.errorCode, message: res.error ?? "Unknown API error fetching the users.")
		}
		return users
	}
	
}
