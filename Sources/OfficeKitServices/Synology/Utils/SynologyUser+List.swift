/*
 * SynologyUser+List.swift
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
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-list> */
	static func getAll(includeSuspended: Bool = false, propertiesToFetch keys: Set<SynologyUser.CodingKeys>?, connector: SynologyConnector) async throws -> [SynologyUser] {
		throw Err.__notImplemented
//		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
//		let mandatoryKeys: Set<SynologyUser.CodingKeys> = [.id, .userPrincipalName]
//		
//		var urlParameters = [String: String]()
//		if !includeSuspended {urlParameters["$filter"] = "accountEnabled eq true"}
//		if let keys {urlParameters["$select"] = keys.union(mandatoryKeys).map{ $0.rawValue }.joined(separator: ",")}
//		
//		let request = try URLRequest(url: baseURL.appending("users").appendingQueryParameters(from: urlParameters))
//		return try await CollectionResponse<SynologyUser>.getAll(sourceRequest: request, requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)])
	}
	
}
