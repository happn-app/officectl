/*
 * GoogleUser.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation

import Email

import OfficeModel



public struct GoogleUser : Hashable, Codable {
	
	public enum Kind : String, Codable {
		
		case user = "admin#directory#user"
		
	}
	
	public enum PasswordHashFunction : String, Codable {
		
		case sha1 = "SHA-1"
		case md5 = "MD5"
		case crypt = "crypt"
		
	}
	
	public struct Name : Codable {
		
		public var givenName: String
		public var familyName: String
		public var fullName: String
		
	}
	
	public var kind: Kind = .user
	@RemoteProperty
	public var etag: String??
	
	@RemoteProperty
	public var id: String?
	@RemoteProperty
	public var customerID: String?
	
	@RemoteProperty
	public var name: Name?
	
	public var primaryEmail: Email
	@RemoteProperty
	public var aliases: [Email]??
	@RemoteProperty
	public var nonEditableAliases: [Email]??
	@RemoteProperty
	public var includeInGlobalAddressList: Bool?
	
	@RemoteProperty
	public var isAdmin: Bool?
	@RemoteProperty
	public var isDelegatedAdmin: Bool?
	
	@RemoteProperty
	public var lastLoginTime: Date??
	@RemoteProperty
	public var creationTime: Date?
	@RemoteProperty
	public var agreedToTerms: Bool?
	
	@RemoteProperty
	public var suspended: Bool?
	@RemoteProperty
	public var hashFunction: PasswordHashFunction??
	@RemoteProperty
	public var password: String??
	@RemoteProperty
	public var changePasswordAtNextLogin: Bool?
	
	public init(email: Email) {
		primaryEmail = email
	}
	
	public static func ==(_ user1: GoogleUser, _ user2: GoogleUser) -> Bool {
		return user1.primaryEmail == user2.primaryEmail
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(primaryEmail)
	}
	
	public func cloneForPatching() -> GoogleUser {
		var ret = GoogleUser(email: primaryEmail)
		ret.id = id
		ret.etag = etag
		return ret
	}
	
	private enum CodingKeys : String, CodingKey {
		case kind, etag
		case id, customerID = "customerId"
		case name
		case primaryEmail, aliases, nonEditableAliases, includeInGlobalAddressList
		case isAdmin, isDelegatedAdmin
		case lastLoginTime, creationTime, agreedToTerms
		case suspended, hashFunction, password, changePasswordAtNextLogin
	}
	
}

extension GoogleUser : DirectoryUser {
	
	public typealias IDType = Email
	public typealias PersistentIDType = String
	
	public var userID: Email {
		return primaryEmail
	}
	
	public var remotePersistentID: RemoteProperty<String> {
		return _id
	}
	
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {
		return .set(primaryEmail)
	}
	
	public var remoteOtherEmails: RemoteProperty<[Email]> {
		return _aliases.map{ $0 ?? [] }
	}
	
	public var remoteFirstName: RemoteProperty<String?> {
		return _name.map{ $0.givenName }
	}
	
	public var remoteLastName: RemoteProperty<String?> {
		return _name.map{ $0.familyName }
	}
	
	public var remoteNickname: RemoteProperty<String?> {
		return .unsupported
	}
	
}
