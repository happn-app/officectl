/*
 * GitHubUser.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/28.
 */

import Foundation

import Email

import OfficeKit2



public struct GitHubUser : Sendable, Hashable, Codable {
	
	/**
	 Should always be `“User”` for a user.
	 
	 (**TODO**: Create an enum with GitHub object types, validate object types, etc.) */
	public var type: String = "User"
	
	public var login: String
	
	public var id: Int?
	public var nodeID: String?
	
	public var name: String?
	
	/** Not really a part of a `GitHubUser` per se (only available when listing org members for instance), but GitHub’s API is weird… */
	public var siteAdmin: Bool?
	public var twoFactorAuthentication: Bool?
	
	/** Will probably be `nil` all the time, and if not, value will be useless. */
	public var email: Email?
	/**
	 Not sure this is actually useful.
	 I’m pretty sure it isn’t tbh.
	 Let’s check that later. */
	public var company: String?
	
	public var membershipType: MembershipType?
	
	public func copyModifying(membershipType: MembershipType) -> Self {
		var ret = self
		ret.membershipType = membershipType
		return ret
	}
	
	public enum MembershipType : Sendable, Codable {
		
		case member
		case invited
		
		case outsideCollaborator
		case pendingCollaborator
		
	}
	
	enum CodingKeys : String, CodingKey {
		
		case type
		
		case login
		
		case id
		case nodeID = "node_id"
		
		case name
		
		case siteAdmin = "site_admin"
		case twoFactorAuthentication = "two_factor_authentication"
		
		case company
		
	}
	
}
