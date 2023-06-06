/*
 * SynologyUser+Get.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import URLRequestOperation

import OfficeKit



extension SynologyUser {
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-update> */
	func update(properties: Set<SynologyUser.CodingKeys>, connector: SynologyConnector) async throws -> SynologyUser {
		throw Err.__notImplemented
//		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
//		
//		guard let userID = id else {
//			throw Err.noPersistentID
//		}
//		
//		/* Data returned is empty. */
//		let op = try URLRequestDataOperation.forData(
//			urlRequest: {
//				var ret = try URLRequest(url: baseURL.appending("users", userID))
//				ret.httpBody = try JSONEncoder().encode(self.forPatching(properties: properties))
//				ret.setValue("application/json", forHTTPHeaderField: "content-type")
//				ret.httpMethod = "PATCH"
//				return ret
//			}(),
//			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
//		)
//		_ = try await op.startAndGetResult().result
//		
//		/* We fetch the user again.
//		 * I’m not sure it’s a good idea, but at least we get fresh values from the server.
//		 * It’s very weird M$ does not return the user after an update. */
//		return try await SynologyUser.get(id: userID, propertiesToFetch: properties, connector: connector)
	}
	
}
