/*
 * GoogleUser+Update.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/12/14.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Email
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit



internal extension GoogleUser {
	
	/* <https://developers.google.com/admin-sdk/directory/reference/rest/v1/users/delete> */
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
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
		)
		_ = try await op.startAndGetResult().result
	}
	
}
