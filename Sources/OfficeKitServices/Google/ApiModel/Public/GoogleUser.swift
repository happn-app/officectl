/*
 * GoogleUser.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/23.
 */

import Foundation

import Email



public struct GoogleUser : Sendable, Hashable, Codable {
	
	public enum Kind : String, Sendable, Codable, Hashable {
		
		case user = "admin#directory#user"
		
	}
	
	public enum PasswordHashFunction : String, Sendable, Codable, Hashable {
		
		case sha1 = "SHA-1"
		case md5 = "MD5"
		case crypt = "crypt"
		
	}
	
	public struct Name : Sendable, Codable, Hashable {
		
		public var givenName: String
		public var familyName: String
		public var fullName: String
		
	}
	
	public var kind: Kind = .user
	public var etag: String?
	
	public var id: String?
	public var customerID: String?
	
	public var name: Name?
	public var thumbnailPhotoUrl: URL?
	
	public var primaryEmail: Email
	public var aliases: [Email]?
	public var nonEditableAliases: [Email]?
	public var includeInGlobalAddressList: Bool?
	
	public var isAdmin: Bool?
	public var isDelegatedAdmin: Bool?
	
	public var lastLoginTime: Date?
	public var creationTime: Date?
	public var agreedToTerms: Bool?
	
	public var suspended: Bool?
	public var passwordHashFunction: PasswordHashFunction?
	public var password: String?
	public var changePasswordAtNextLogin: Bool?
	public var isEnrolledIn2Sv: Bool?
	public var isEnforcedIn2Sv: Bool?
	
	public var recoveryEmail: Email?
	public var recoveryPhone: String?
	
	public init(email: Email) {
		primaryEmail = email
	}
	
	public func cloneForPatching() -> GoogleUser {
		var ret = GoogleUser(email: primaryEmail)
		ret.id = id
		ret.etag = etag
		return ret
	}
	
	internal enum CodingKeys : String, CodingKey {
		case kind, etag
		case id, customerID = "customerId"
		case name, thumbnailPhotoUrl
		case primaryEmail, aliases, nonEditableAliases, includeInGlobalAddressList
		case isAdmin, isDelegatedAdmin
		case lastLoginTime, creationTime, agreedToTerms
		case suspended, passwordHashFunction = "hashFunction", password, changePasswordAtNextLogin, isEnrolledIn2Sv, isEnforcedIn2Sv
		case recoveryEmail, recoveryPhone
	}
	
}
