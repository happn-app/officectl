/*
 * GoogleUser+Update.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/12/14.
 */

import Foundation

import Email
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit2



internal extension GoogleUser {
	
	/* https://developers.google.com/admin-sdk/directory/reference/rest/v1/users/delete */
	func delete(connector: GoogleConnector) async throws {
		let baseURL = URL(string: "https://admin.googleapis.com/admin/directory/v1/")!
		
		guard let userID = id else {
			throw Err.noPersistentID
		}
		
		/* Data returned is empty. */
		let op = try URLRequestDataOperation.forData(
			urlRequest: {
				var ret = try URLRequest(url: baseURL.appending("users", userID))
				ret.httpMethod = "DELETE"
				return ret
			}(),
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		_ = try await op.startAndGetResult().result
	}
	
}
