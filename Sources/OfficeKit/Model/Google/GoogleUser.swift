/*
 * GoogleUser.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



public struct GoogleUser : Codable {
	
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
	
}
