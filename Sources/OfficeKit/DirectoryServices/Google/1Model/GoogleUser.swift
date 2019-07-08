/*
 * GoogleUser.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



public struct GoogleUser : Hashable, Codable {
	
	#warning("TODO: Migrate all keys to RemoteProperty")
	
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
	
	public var kind: Kind
	public var etag: String?
	
	/** The id of the user. If empty, the id has not been fetched. */
	public var id: String
	/** The customer id of the user. If empty, the id has not been fetched. */
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
	public var hashFunction: PasswordHashFunction?
	public var password: String?
	public var changePasswordAtNextLogin: Bool
	
	init(email: Email) {
		kind = .user
		etag = nil
		
		id = ""
		customerId = ""
		
		name = Name(givenName: "", familyName: "", fullName: "")
		
		primaryEmail = email
		aliases = nil
		nonEditableAliases = nil
		includeInGlobalAddressList = false
		
		isAdmin = false
		isDelegatedAdmin = false
		
		lastLoginTime = nil
		creationTime = Date()
		agreedToTerms = false
		
		suspended = false
		hashFunction = nil
		password = nil
		changePasswordAtNextLogin = false
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
		return (id.isEmpty ? .unfetched : .fetched(id))
	}
	
	public var emails: RemoteProperty<[Email]> {
		return .fetched([primaryEmail] + (aliases ?? []))
	}
	
	public var firstName: RemoteProperty<String?> {
		return .fetched(name.givenName)
	}
	
	public var lastName: RemoteProperty<String?> {
		return .fetched(name.familyName)
	}
	
	public var nickname: RemoteProperty<String?> {
		return .unsupported
	}
	
}
