/*
 * GitHubUser+List.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/29.
 */

import Foundation

import CollectionConcurrencyKit
import OperationAwaiting
import URLRequestOperation

import OfficeKit



extension GitHubUser {
	
	/* <https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#list-organization-members>
	 * <https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#list-pending-organization-invitations>
	 * <https://docs.github.com/en/rest/orgs/outside-collaborators?apiVersion=2022-11-28#list-outside-collaborators-for-an-organization>
	 * Did not find endpoint for listing pending collaborators, sadly. */
	static func list(orgID: String, connector: GitHubConnector) async throws -> [GitHubUser] {
		let baseURL = GitHubConnector.apiURL
		
		let membershipTypes = [
			(["orgs", orgID, "members"], false),
			(["orgs", orgID, "invitations"], true),
			(["orgs", orgID, "outside_collaborators"], false),
			/* I did not find the endpoint in GH API for fetching pending collaborators.
			 * I’m pretty sure it does not exist yet (2022-12-30). */
		]
		return try await membershipTypes.asyncFlatMap{ membershipType in
			let (pathComponents, isInviteEndpoint) = membershipType
			
			if !isInviteEndpoint {return try await  Utils.getAll(baseURL: baseURL, pathComponents: pathComponents, connector: connector) as [GitHubUser]}
			else                 {return try await (Utils.getAll(baseURL: baseURL, pathComponents: pathComponents, connector: connector) as [Invite]).map{ $0.invitee }}
		}
	}
	
}
