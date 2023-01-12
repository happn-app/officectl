/*
 * GitHubUser+Delete.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/29.
 */

import Foundation

import OperationAwaiting
import URLRequestOperation

import OfficeKit



extension GitHubUser {
	
	static func get(id: Int, orgID: String, connector: GitHubConnector) async throws -> GitHubUser? {
		let baseURL = GitHubConnector.apiURL
		
		let userLogin = try await URLRequestDataOperation<GitHubUser>.forAPIRequest(
			url: baseURL.appending("user", String(id)),
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		).startAndGetResult().result.login
		return try await get(login: userLogin, orgID: orgID, connector: connector)
	}
	
	static func get(login: String, orgID: String, connector: GitHubConnector) async throws -> GitHubUser? {
		let (membershipType, user) = try await MembershipType.fetch(for: login, orgID: orgID, connector: connector)
		return (membershipType != .none ? user : nil)
	}
	
}
