/*
 * GoogleUser+Get.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/29.
 */

import Foundation

import Email
import GenericJSON
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit



internal extension GoogleUser {
	
	/* <https://developers.google.com/admin-sdk/directory/v1/reference/users/get> */
	static func search(_ request: SearchRequest, propertiesToFetch keys: Set<GoogleUser.CodingKeys>?, connector: GoogleConnector) async throws -> [GoogleUser] {
		var token: String?
		var res = [GoogleUser]()
		repeat {
			let newUsersList = try await fetchNextPage(request: request, fields: keys ?? [], nextPageToken: token, connector: connector)
			token = newUsersList.nextPageToken
			res += newUsersList.users ?? []
		} while token != nil
		return res
	}
	
	private static func fetchNextPage(request: SearchRequest, fields: Set<GoogleUser.CodingKeys>, nextPageToken: String?, connector: GoogleConnector) async throws -> GoogleUsersList {
		let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/")!
		let queryParams = RequestQuery(domain: request.domain, query: request.query, projection: "BASIC", pageToken: nextPageToken)
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = Conf.dateDecodingStrategy
		let op = try URLRequestDataOperation<GoogleUsersList>.forAPIRequest(
			url: baseURL.appendingPathComponentsSafely("users"), urlParameters: queryParams,
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await op.startAndGetResult().result
		
		struct RequestQuery : Encodable {
			var domain: String
			var query: String?
			var projection: String
			var pageToken: String?
		}
	}
	
}


internal struct SearchRequest : Sendable {
	
	let domain: String
	/**
	 The query for the search.
	 
	 If `nil`, the search will return all users in the given domain.
	 No validation on the query is done.
	 
	 The format is described here: <https://developers.google.com/admin-sdk/directory/v1/guides/search-users>. */
	let query: String?
	
	init(domain d: String, query q: String?) {
		query = q
		domain = d
	}
	
}
