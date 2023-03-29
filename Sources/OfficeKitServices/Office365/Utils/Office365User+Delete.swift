/*
 * Office365User+Get.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/03/27.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import URLRequestOperation

import OfficeKit



extension Office365User {
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-delete> */
	func delete(connector: Office365Connector) async throws {
		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
		
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
