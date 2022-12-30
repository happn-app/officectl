/*
 * GoogleUser.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/23.
 */

import Foundation

import Email

import OfficeKit2



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
		
		public var givenName: String?
		public var familyName: String?
		public var fullName: String? /* Non-editable directly (must use givenName or familyName to update). */
		
		public var displayName: String?
		
		public init(givenName: String? = nil, familyName: String? = nil) {
			self.givenName = givenName
			self.familyName = familyName
		}
		
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
	
	public var isSuspended: Bool?
	public var passwordHashFunction: PasswordHashFunction?
	public var password: String?
	public var changePasswordAtNextLogin: Bool?
	public var isEnrolledIn2Sv: Bool?
	public var isEnforcedIn2Sv: Bool?
	
	@EmptyIsNil
	public var recoveryEmail: Email?
	public var recoveryPhone: String?
	
	public init(email: Email) {
		primaryEmail = email
	}
	
	internal func forPatching(properties: Set<CodingKeys>) -> GoogleUser {
		var ret = GoogleUser(email: primaryEmail)
		ret.id = id
		ret.etag = etag
		ret.kind = kind
		for property in properties {
			switch property {
				case .id, .etag, .kind: (/*nop*/)
				case .customerID:                 ret.customerID                 = customerID
				case .name:                       ret.name                       = name
				case .thumbnailPhotoUrl:          ret.thumbnailPhotoUrl          = thumbnailPhotoUrl
				case .primaryEmail:               ret.primaryEmail               = primaryEmail
				case .aliases:                    ret.aliases                    = aliases
				case .nonEditableAliases:         ret.nonEditableAliases         = nonEditableAliases
				case .includeInGlobalAddressList: ret.includeInGlobalAddressList = includeInGlobalAddressList
				case .isAdmin:                    ret.isAdmin                    = isAdmin
				case .isDelegatedAdmin:           ret.isDelegatedAdmin           = isDelegatedAdmin
				case .lastLoginTime:              ret.lastLoginTime              = lastLoginTime
				case .creationTime:               ret.creationTime               = creationTime
				case .agreedToTerms:              ret.agreedToTerms              = agreedToTerms
				case .isSuspended:                ret.isSuspended                = isSuspended
				case .passwordHashFunction:       ret.passwordHashFunction       = passwordHashFunction
				case .password:                   ret.password                   = password
				case .changePasswordAtNextLogin:  ret.changePasswordAtNextLogin  = changePasswordAtNextLogin
				case .isEnrolledIn2Sv:            ret.isEnrolledIn2Sv            = isEnrolledIn2Sv
				case .isEnforcedIn2Sv:            ret.isEnforcedIn2Sv            = isEnforcedIn2Sv
				case .recoveryEmail:              ret.recoveryEmail              = recoveryEmail
				case .recoveryPhone:              ret.recoveryPhone              = recoveryPhone
			}
		}
		return ret
	}
	
	internal enum CodingKeys : String, CodingKey {
		case kind, etag
		case id, customerID = "customerId"
		case name, thumbnailPhotoUrl
		case primaryEmail, aliases, nonEditableAliases, includeInGlobalAddressList
		case isAdmin, isDelegatedAdmin
		case lastLoginTime, creationTime, agreedToTerms
		case isSuspended = "suspended", passwordHashFunction = "hashFunction", password, changePasswordAtNextLogin, isEnrolledIn2Sv, isEnforcedIn2Sv
		case recoveryEmail, recoveryPhone
	}
	
}
