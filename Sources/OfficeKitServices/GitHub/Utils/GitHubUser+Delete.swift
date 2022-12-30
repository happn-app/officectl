/*
 * GitHubUser+Delete.swift
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
	
	/* <https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#remove-organization-membership-for-a-user>
	 * <https://docs.github.com/en/rest/orgs/outside-collaborators?apiVersion=2022-11-28#remove-outside-collaborator-from-an-organization> */
	func delete(orgID: String, connector: GitHubConnector) async throws {
		let baseURL = GitHubConnector.apiURL
		
		let (membershipType, _) = try await MembershipType.fetch(for: login, orgID: orgID, connector: connector)
		switch membershipType {
			case .member:
				_ = try await URLRequestDataOperation.forData(
					urlRequest: {
						var ret = try URLRequest(url: baseURL.appending("orgs", orgID, "memberships", login))
						ret.httpMethod = "DELETE"
						return ret
					}(),
					requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				).startAndGetResult()
				
			case .outsideCollaborator:
				_ = try await URLRequestDataOperation.forData(
					urlRequest: {
						var ret = try URLRequest(url: baseURL.appending("orgs", orgID, "outside_collaborators", login))
						ret.httpMethod = "DELETE"
						return ret
					}(),
					requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				).startAndGetResult()
				
			case .none:
				(/*nop*/)
		}
	}
	
}
