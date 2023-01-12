/*
 * MembershipType.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation

import OperationAwaiting
import URLRequestOperation

import OfficeKit



enum MembershipType : Equatable {
	
	case member(isPending: Bool)
	case outsideCollaborator
	case none
	
	/* <https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#get-organization-membership-for-a-user> */
	static func fetch(for login: String, orgID: String, connector: GitHubConnector) async throws -> (membershipType: Self, user: GitHubUser) {
		let baseURL = GitHubConnector.apiURL
		
		do {
			let membership = try await URLRequestDataOperation<Membership>.forAPIRequest(
				url: baseURL.appending("orgs", orgID, "memberships", login),
				requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
			).startAndGetResult().result
			return (.member(isPending: membership.state == .pending), membership.user)
		} catch let error as URLRequestOperationError where error.unexpectedStatusCodeError?.actual == 404 {
			/* We got a 404 error: the user is not a member of the organization.
			 *
			 * Is it an outside collaborator?
			 * Sadly, AFAICT, we have to fetch the entire list of outside collaborators to answer this question… */
			let outsideCollaborators: [GitHubUser] = try await Utils.getAll(baseURL: baseURL, pathComponents: ["orgs", orgID, "outside_collaborators"], connector: connector)
			if let user = outsideCollaborators.first(where: { $0.login == login }) {
				return (.outsideCollaborator, user)
			} else {
				return (.none, GitHubUser(login: login))
			}
		}
	}
	
}
