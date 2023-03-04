/*
 * Office365User+List.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/03/03.
 */

import Foundation

import URLRequestOperation

import OfficeKit



extension Office365User {
	
	/* <https://learn.microsoft.com/en-us/graph/api/user-list> */
	static func getAll(includeSuspended: Bool = false, propertiesToFetch keys: Set<Office365User.CodingKeys>?, connector: Office365Connector) async throws -> [Office365User] {
		let baseURL = URL(string: "https://graph.microsoft.com/v1.0/")!
		let mandatoryKeys: Set<Office365User.CodingKeys> = [.id, .userPrincipalName]
		
		var urlParameters = [String: String]()
		if !includeSuspended {urlParameters["$filter"] = "accountEnabled eq true"}
		if let keys {urlParameters["$select"] = keys.union(mandatoryKeys).map{ $0.rawValue }.joined(separator: ",")}
		
		let decoder = SendableJSONDecoder{ _ in }
		let op = try URLRequestDataOperation<CollectionResponse<Office365User>>.forAPIRequest(
			url: try baseURL.appending("users"), urlParameters: urlParameters,
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
#warning("TODO: Next link!")
		return try await op.startAndGetResult().result.value
	}
	
}
