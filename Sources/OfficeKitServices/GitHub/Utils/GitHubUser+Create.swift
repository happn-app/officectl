/*
 * GitHubUser+Create.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/29.
 */

import Foundation

import CollectionConcurrencyKit
import OperationAwaiting
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit2



extension GitHubUser {
	
	/* <https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#create-an-organization-invitation>
	 * <https://docs.github.com/en/rest/users/users?apiVersion=2022-11-28#get-a-user> */
	func create(role: Role, teamIDs: Set<Int> = [], orgID: String, connector: GitHubConnector) async throws -> GitHubUser {
		let baseURL = GitHubConnector.apiURL
		
		let nonOptionalID: Int
		if let id {
			nonOptionalID = id
		} else {
			/* Let’s fetch the id. */
			let op = try URLRequestDataOperation<GitHubUser>.forAPIRequest(
				url: baseURL.appending("users", login),
				requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
			)
			nonOptionalID = try await op.startAndGetResult().result.id ?! Err.loginNotFound
		}
		
		let op = try URLRequestDataOperation<Invite>.forAPIRequest(
			url: baseURL.appending("orgs", orgID, "invitations"), httpBody: InviteRequestBody(inviteeID: nonOptionalID, role: role, teamIDs: teamIDs),
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await op.startAndGetResult().result.invitee
	}
	
}
