/*
 * Invite.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation

import OfficeKit2



/* Note: This type of object does not have a “type” field from GitHub’s API. */
struct Invite : Codable, Sendable {
	
	var id: Int?
	var nodeID: String?
	
	var inviteeLogin: String
	/**
	 This is the role of the _invitee_.
	 For a user who is already a member, this should be `nil`. */
	var inviteeRole: InviteeRole?
	
	/** We created the invite? */
	var inviter: GitHubUser?
	
	@EmptyIsNil
	var failureDate: Date?
	@EmptyIsNil
	var failureReason: String?
	
	var teamCount: Int
	
	var invitee: GitHubUser {
		return .init(login: inviteeLogin)
	}
	
	enum CodingKeys : String, CodingKey {
		
		case id
		case nodeID = "node_id"
		
		case inviteeLogin = "login"
		case inviteeRole = "role"
		
		case inviter
		
		case failureDate = "failed_at"
		case failureReason = "failed_reason"
		
		case teamCount = "team_count"
		
	}
	
}
