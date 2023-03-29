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
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-post-users> */
	func create(connector: Office365Connector) async throws -> Office365User {
		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
		
		let op = try URLRequestDataOperation<Office365User>.forAPIRequest(
			url: baseURL.appending("users"), httpBody: self,
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
		)
		return try await op.startAndGetResult().result
	}
	
}
