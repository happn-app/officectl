/*
 * GoogleUser.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



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
	
	public var kind: RemoteProperty<Kind> = .unfetched
	public var etag: RemoteProperty<String?> = .unfetched
	
	public var id: RemoteProperty<String> = .unfetched
	public var customerId: RemoteProperty<String> = .unfetched
	
	public var name: RemoteProperty<Name> = .unfetched
	
	public var primaryEmail: Email
	public var aliases: RemoteProperty<[Email]?> = .unfetched
	public var nonEditableAliases: RemoteProperty<[Email]?> = .unfetched
	public var includeInGlobalAddressList: RemoteProperty<Bool> = .unfetched
	
	public var isAdmin: RemoteProperty<Bool> = .unfetched
	public var isDelegatedAdmin: RemoteProperty<Bool> = .unfetched
	
	public var lastLoginTime: RemoteProperty<Date?> = .unfetched
	public var creationTime: RemoteProperty<Date> = .unfetched
	public var agreedToTerms: RemoteProperty<Bool> = .unfetched
	
	public var suspended: RemoteProperty<Bool> = .unfetched
	public var hashFunction: RemoteProperty<PasswordHashFunction?> = .unfetched
	public var password: RemoteProperty<String?> = .unfetched
	public var changePasswordAtNextLogin: RemoteProperty<Bool> = .unfetched
	
	init(email: Email) {
		primaryEmail = email
	}
	
	public static func ==(_ user1: GoogleUser, _ user2: GoogleUser) -> Bool {
		return user1.id == user2.id
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
	/** The `CodingKeys` for the `GoogleUser`. We give a public access to this
	enum in order to be able to pass it to `ModifyGoogleUserOperation`.
	
	- Note: Sadly this implies that this enum must be modified whenever a new
	property is added/removed from `GoogleUser`. And the compiler won’t notify
	you… */
	public enum CodingKeys : String, CodingKey {
		case kind, etag
		case id, customerId
		case name
		case primaryEmail, aliases, nonEditableAliases, includeInGlobalAddressList
		case isAdmin, isDelegatedAdmin
		case lastLoginTime, creationTime, agreedToTerms
		case suspended, hashFunction, password, changePasswordAtNextLogin
	}
	
	let objectCreationDate = Date()
	
}

extension GoogleUser : DirectoryUser {
	
	public typealias UserIdType = Email
	public typealias PersistentIdType = String
	
	public var userId: Email {
		return primaryEmail
	}
	
	public var persistentId: RemoteProperty<String> {
		return id
	}
	
	public var emails: RemoteProperty<[Email]> {
		return aliases.map{ [primaryEmail] + ($0 ?? []) }
	}
	
	public var firstName: RemoteProperty<String?> {
		return name.map{ $0.givenName }
	}
	
	public var lastName: RemoteProperty<String?> {
		return name.map{ $0.familyName }
	}
	
	public var nickname: RemoteProperty<String?> {
		return .unsupported
	}
	
}
