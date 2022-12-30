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

import OfficeKit2



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
			
			let nPerPage = 100 /* max possible */
			var pageNumber = 1
			var curResult: [GitHubUser]
			var allResults = [GitHubUser]()
			repeat {
				if !isInviteEndpoint {
					let op = try URLRequestDataOperation<[GitHubUser]>.forAPIRequest(
						url: baseURL.appendingPathComponentsSafely(pathComponents).appendingQueryParameters(from: ["per_page": nPerPage, "page": pageNumber]),
						requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
					)
					curResult = try await op.startAndGetResult().result.map{ $0 }
				} else {
					let op = try URLRequestDataOperation<[Invite]>.forAPIRequest(
						url: baseURL.appendingPathComponentsSafely(pathComponents).appendingQueryParameters(from: ["per_page": nPerPage, "page": pageNumber]),
						requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
					)
					curResult = try await op.startAndGetResult().result.map{ $0.invitee }
				}
				allResults.append(contentsOf: curResult)
				pageNumber += 1
			} while curResult.count >= nPerPage
			return allResults
		}
	}
	
}
