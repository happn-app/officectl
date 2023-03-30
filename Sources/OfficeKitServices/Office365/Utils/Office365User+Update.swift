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
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-update> */
	func update(properties: Set<Office365User.CodingKeys>, connector: Office365Connector) async throws -> Office365User {
		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
		
		guard let userID = id else {
			throw Err.noPersistentID
		}
		
		/* Data returned is empty. */
		let op = try URLRequestDataOperation.forData(
			urlRequest: {
				var ret = try URLRequest(url: baseURL.appending("users", userID))
				ret.httpBody = try JSONEncoder().encode(self.forPatching(properties: properties))
				ret.setValue("application/json", forHTTPHeaderField: "content-type")
				ret.httpMethod = "PATCH"
				return ret
			}(),
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
		)
		_ = try await op.startAndGetResult().result
		
		/* We fetch the user again.
		 * I’m not sure it’s a good idea, but at least we get fresh values from the server.
		 * It’s very weird M$ does not return the user after an update. */
		return try await Office365User.get(id: userID, propertiesToFetch: properties, connector: connector)
	}
	
}
