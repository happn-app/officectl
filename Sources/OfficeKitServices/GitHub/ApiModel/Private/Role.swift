/*
 * Role.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation



enum MembershipRole : String, Sendable, Codable {
	
	case admin
	case member = "member"
	case billingManager = "billing_manager"
	
}

/* Mostly the same as the membership role, but member has another name… */
enum InviteeRole : String, Sendable, Codable {
	
	case admin
	case directMember = "direct_member"
	case billingManager = "billing_manager"
	
}
