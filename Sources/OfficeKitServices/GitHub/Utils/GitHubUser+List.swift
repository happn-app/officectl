/*
 * GitHubUser+List.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/29.
 */

import Foundation

import URLRequestOperation
import OperationAwaiting

import OfficeKit2



extension GitHubUser {
	
	/* https://developers.google.com/admin-sdk/directory/v1/reference/users/get */
	static func list(orgID: String, propertiesToFetch keys: Set<GitHubUser.CodingKeys>?, connector: GitHubConnector) async throws -> [GitHubUser] {
		let baseURL = GitHubConnector.apiURL
		
		let decoder = JSONDecoder()
		let op = try URLRequestDataOperation<[GitHubUser]>.forAPIRequest(
			url: baseURL.appending("orgs", orgID, "members"),
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await op.startAndGetResult().result
	}
	
}
