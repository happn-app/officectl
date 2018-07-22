/*
 * GoogleUser.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



public struct GoogleUser : Hashable, Codable {
	
	public enum Kind: String, Codable {
		
		case user = "admin#directory#user"
		
	}
	
	public struct Name : Codable {
		
		var givenName: String
		var familyName: String
		var fullName: String
		
	}
	
	public var kind: Kind
	public var etag: String?
	
	public var id: String
	public var customerId: String
	
	public var name: Name
	
	public var primaryEmail: Email
	public var aliases: [Email]?
	public var nonEditableAliases: [Email]?
	public var includeInGlobalAddressList: Bool
	
	public var isAdmin: Bool
	public var isDelegatedAdmin: Bool
	
	public var lastLoginTime: Date?
	public var creationTime: Date
	public var agreedToTerms: Bool
	
	public var suspended: Bool
	public var changePasswordAtNextLogin: Bool
	
	public static func ==(_ user1: GoogleUser, _ user2: GoogleUser) -> Bool {
		return user1.id == user2.id
	}
	
	#if swift(>=4.2)
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	#else
	public var hashValue: Int {
		return id.hashValue
	}
	#endif
	
	#if os(Linux)
		/* We can get rid of this when Linux supports keyDecodingStrategy */
		private enum CodingKeys : String, CodingKey {
			case kind, etag
			case id, customerId = "customer_id"
			case name
			case primaryEmail = "primary_email", aliases, nonEditableAliases = "non_editable_aliases", includeInGlobalAddressList = "include_in_global_address_list"
			case isAdmin = "is_admin", isDelegatedAdmin = "is_delegated_admin"
			case lastLoginTime = "last_login_time", creationTime = "creation_time", agreedToTerms = "agreed_to_terms"
			case suspended, changePasswordAtNextLogin = "change_password_at_next_login"
		}
	#endif
	
}
