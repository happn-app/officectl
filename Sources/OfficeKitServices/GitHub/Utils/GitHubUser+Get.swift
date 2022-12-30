/*
 * GitHubUser+Delete.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/29.
 */

import Foundation



extension GitHubUser {
	
	static func get(id: String, orgID: String, connector: GitHubConnector) async throws -> GitHubUser? {
		let (membershipType, user) = try await MembershipType.fetch(for: id, orgID: orgID, connector: connector)
		return (membershipType != .none ? user : nil)
	}
	
}
