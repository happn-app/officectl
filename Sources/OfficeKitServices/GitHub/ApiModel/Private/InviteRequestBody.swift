/*
 * InviteRequestBody.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation



struct InviteRequestBody : Codable, Sendable {
	
	var inviteeID: Int /* or email, but we don’t care, we only invite through id. */
	var role: Invite.Role
	
	var teamIDs: Set<Int> = []
	
	private enum CodingKeys: String, CodingKey {
		
		case inviteeID = "invitee_id"
		case role
		case teamIDs = "team_ids"
		
	}
	
}
