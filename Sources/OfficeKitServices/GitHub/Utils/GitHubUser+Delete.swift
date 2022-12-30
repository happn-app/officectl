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
	 * <https://docs.github.com/en/rest/orgs/outside-collaborators?apiVersion=2022-11-28#remove-outside-collaborator-from-an-organization>
	 *
	 * <https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#get-organization-membership-for-a-user> */
	func delete(orgID: String, connector: GitHubConnector) async throws {
		let baseURL = GitHubConnector.apiURL
		
		/* First fetch the membership type (the endpoints are different depending on the membership type). */
		enum MembershipType {
			case member(isPending: Bool)
			case outsideCollaborator
		}
		let membershipType: MembershipType
		do {
			let membership = try await URLRequestDataOperation<Membership>.forAPIRequest(
				url: baseURL.appending("orgs", orgID, "memberships", login),
				requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
			).startAndGetResult().result
			membershipType = .member(isPending: membership.state == .pending)
		} catch let error as URLRequestOperationError where error.unexpectedStatusCodeError?.actual == 404 {
			/* We got a 404 error: the user is not a member of the organization.
			 * Is it an outside collaborator?
			 * We’ll assume he is. */
			membershipType = .outsideCollaborator
		}
		
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
		}
	}
	
}
