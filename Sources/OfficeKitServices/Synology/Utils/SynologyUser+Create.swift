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
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-post-users> */
	func create(connector: SynologyConnector) async throws -> SynologyUser {
		throw Err.__notImplemented
//		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
//		
//		let op = try URLRequestDataOperation<SynologyUser>.forAPIRequest(
//			url: baseURL.appending("users"), httpBody: self,
//			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
//		)
//		return try await op.startAndGetResult().result
	}
	
}
