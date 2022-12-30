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
	
	/* https://developers.google.com/admin-sdk/directory/v1/reference/users/get */
	static func list(
		membershipTypes: Set<GitHubUser.MembershipType> = [.member, .invited, .outsideCollaborator],
		orgID: String,
		connector: GitHubConnector
	) async throws -> [GitHubUser] {
		let baseURL = GitHubConnector.apiURL
		
		return try await membershipTypes.asyncFlatMap{ membershipType in
			let pathComponents: [String]
			switch membershipType {
				case .member:              pathComponents = ["orgs", orgID, "members"]
				case .invited:             pathComponents = ["orgs", orgID, "invitations"]
				case .outsideCollaborator: pathComponents = ["orgs", orgID, "outside_collaborators"]
				case .pendingCollaborator: throw Err.unsupportedOperation /* I did not find the endpoint in GH API (I’m pretty sure it does not exist yet (2022-12-30). */
			}
			let nPerPage = 100 /* max possible */
			var pageNumber = 1
			var curResult: [GitHubUser]
			var allResults = [GitHubUser]()
			repeat {
				let op = try URLRequestDataOperation<[GitHubUser]>.forAPIRequest(
					url: baseURL.appendingPathComponentsSafely(pathComponents).appendingQueryParameters(from: ["per_page": nPerPage, "page": pageNumber]),
					requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
				)
				curResult = try await op.startAndGetResult().result.map{ $0.copyModifying(membershipType: membershipType) }
				allResults.append(contentsOf: curResult)
				pageNumber += 1
			} while curResult.count >= nPerPage
			return allResults
		}
	}
	
}
