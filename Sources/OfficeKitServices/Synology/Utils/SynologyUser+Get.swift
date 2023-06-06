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
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-get>
	 * The ID can be either an actual ID (currently a UUID) or a userPrincipalName. */
	static func get(id: String, propertiesToFetch keys: Set<SynologyUser.CodingKeys>?, connector: SynologyConnector) async throws -> SynologyUser {
		throw Err.__notImplemented
//		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
//		let mandatoryKeys: Set<SynologyUser.CodingKeys> = [.id, .userPrincipalName]
//		
//		var urlParameters = [String: String]()
//		if let keys {urlParameters["$select"] = keys.union(mandatoryKeys).map{ $0.rawValue }.joined(separator: ",")}
//		
//		let op = URLRequestDataOperation<SynologyUser>.forAPIRequest(
//			urlRequest: try URLRequest(url: baseURL.appending("users", id).appendingQueryParameters(from: urlParameters)),
//			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
//		)
//		return try await op.startAndGetResult().result
	}
	
}
