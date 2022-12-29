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
		let op1 = try URLRequestDataOperation<[GitHubUser]>.forAPIRequest(
			url: baseURL.appending("orgs", orgID, "members"),
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		let currentMembers = try await op1.startAndGetResult().result
		
		let op2 = try URLRequestDataOperation<[GitHubUser]>.forAPIRequest(
			url: baseURL.appending("orgs", orgID, "invitations"),
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		let invitedMembers = try await op2.startAndGetResult().result
		return currentMembers + invitedMembers
	}
	
}
