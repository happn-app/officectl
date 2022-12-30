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
	
	/* https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#list-organization-members
	 * https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#list-pending-organization-invitations
	 * https://docs.github.com/en/rest/orgs/outside-collaborators?apiVersion=2022-11-28#list-outside-collaborators-for-an-organization
	 * Did not find endpoint for listing pending collaborators, sadly. */
	static func list(
		membershipTypes: Set<GitHubUser.MembershipType> = [.member, .invited, .outsideCollaborator],
		orgID: String,
		connector: GitHubConnector
	) async throws -> [GitHubUser] {
		let baseURL = GitHubConnector.apiURL
		
		return try await membershipTypes.asyncFlatMap{ membershipType in
			let isInvite: Bool
			let pathComponents: [String]
			switch membershipType {
				case .member:              (isInvite, pathComponents) = (false, ["orgs", orgID, "members"])
				case .invited:             (isInvite, pathComponents) = (true,  ["orgs", orgID, "invitations"])
				case .outsideCollaborator: (isInvite, pathComponents) = (false, ["orgs", orgID, "outside_collaborators"])
				case .pendingCollaborator: throw Err.unsupportedOperation /* I did not find the endpoint in GH API (I’m pretty sure it does not exist yet (2022-12-30). */
			}
			let nPerPage = 100 /* max possible */
			var pageNumber = 1
			var curResult: [GitHubUser]
			var allResults = [GitHubUser]()
			repeat {
				if !isInvite {
					let op = try URLRequestDataOperation<[GitHubUser]>.forAPIRequest(
						url: baseURL.appendingPathComponentsSafely(pathComponents).appendingQueryParameters(from: ["per_page": nPerPage, "page": pageNumber]),
						requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
					)
					curResult = try await op.startAndGetResult().result.map{ $0.copyModifying(membershipType: membershipType) }
				} else {
					let op = try URLRequestDataOperation<[Invite]>.forAPIRequest(
						url: baseURL.appendingPathComponentsSafely(pathComponents).appendingQueryParameters(from: ["per_page": nPerPage, "page": pageNumber]),
						requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
					)
					curResult = try await op.startAndGetResult().result.map{ $0.invitee.copyModifying(membershipType: membershipType) }
				}
				allResults.append(contentsOf: curResult)
				pageNumber += 1
			} while curResult.count >= nPerPage
			return allResults
		}
	}
	
}
