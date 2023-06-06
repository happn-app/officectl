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
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-delete> */
	func delete(connector: SynologyConnector) async throws {
		throw Err.__notImplemented
//		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
//		
//		guard let userID = id else {
//			/* Technically we could also use the userPrincipalName. */
//			throw Err.noPersistentID
//		}
//		
//		/* Data returned is empty. */
//		let op = try URLRequestDataOperation.forData(
//			urlRequest: {
//				var ret = try URLRequest(url: baseURL.appending("users", userID))
//				ret.httpMethod = "DELETE"
//				return ret
//			}(),
//			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
//		)
//		_ = try await op.startAndGetResult().result
	}
	
}
