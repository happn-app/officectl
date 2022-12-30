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
	 
	 This is optional because it’s not returned when retrieving the invitations for a company.
	 
	 (**TODO**: Create an enum with GitHub object types, validate object types, etc.) */
	@DefaultForAbsentValue<DefaultTypeProvider>
	public var type: String
	
	public var login: String
	
	public var id: Int?
	public var nodeID: String?
	
	public var name: String?
	
	public var siteAdmin: Bool?
	public var twoFactorAuthentication: Bool?
	
	/** Will probably be `nil` all the time, and if not, value will be useless. */
	public var email: Email?
	/**
	 Not sure this is actually useful.
	 I’m pretty sure it isn’t tbh.
	 Let’s check that later. */
	public var company: String?
	
	/**
	 Who invited the user to the organization?
	 
	 Not truly a part of a user per se.
	 
	 It _should_ be a part of an invitation object,
	  but GitHub does not have an “invite” object and put everything in the user object.
	 
	 To be more precise, it seem the concept of “object” does not exist at all in GitHub’s (REST) API:
	  the API is just a bunch of properties returned per endpoint, validated by a schema.
	 
	 Anyway, the “proper” way to handle this would probably be to create one kind of object per API endpoint.
	 
	 We won’t do that.
	 
	 So instead we put the inviter directly inside the User object. */
	@Indirect
	public var inviter: GitHubUser?
	/**
	 This is the role of the _invitee_.
	 For a user who is already a member, this should be `nil`. */
	public var inviteeRole: Role?
	
	public var invitationFailureDate: Date?
	public var invitationFailureReason: String?
	
	@DefaultForAbsentValue<DefaultMembershipTypeProvider>
	public var membershipType: MembershipType?
	
	public func copyModifying(membershipType: MembershipType) -> Self {
		var ret = self
		ret.membershipType = membershipType
		return ret
	}
	
	public enum Role : String, Sendable, Codable {
		
		case admin
		case directMember = "direct_member"
		case billingManager = "billing_manager"
		
	}
	
	public enum MembershipType : Sendable, Codable {
		
		case member
		case invited
		
		case outsideCollaborator
		case pendingCollaborator
		
	}
	
	public struct DefaultTypeProvider : DefaultValueProvider {
		public static var defaultValue: String = "User"
	}
	public struct DefaultMembershipTypeProvider : DefaultValueProvider {
		public static var defaultValue: MembershipType? = nil
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
		
		case inviter
		case inviteeRole = "role"
		
		case invitationFailureDate = "failed_at"
		case invitationFailureReason = "failed_reason"
		
	}
	
}
