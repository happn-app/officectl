/*
 * Membership.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation



struct Membership : Codable, Sendable {
	
	enum State : String, Codable, Sendable {
		
		case active
		case pending
		
	}
	
	var state: State
	var role: MembershipRole
	
//	var organization: GitHubOrganization
	var user: GitHubUser
	
}
