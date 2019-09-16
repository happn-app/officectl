/*
 * GoogleUser.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation

import Crypto



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
	
	#warning("""
	TODO: I did not find a way to automate this. Ideally I’d have liked to have a
	`nil`-like implementation of RemoteProperty that would drop absent keys
	automatically (from encoding and decoding) but this does not seem possible.
	So instead I do the same thing manually… A thing to check would be code
	generation. This seems like a good candidate for code generation.
	""")
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		kind = try container.decode(Kind.self, forKey: .kind)
		etag = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .etag) ?? .unset
		
		id = try container.decodeIfPresent(RemoteProperty<String>.self, forKey: .id) ?? .unset
		customerId = try container.decodeIfPresent(RemoteProperty<String>.self, forKey: .customerId) ?? .unset
		
		name = try container.decodeIfPresent(RemoteProperty<Name>.self, forKey: .name) ?? .unset
		
		primaryEmail = try container.decode(Email.self, forKey: .primaryEmail)
		aliases = try container.decodeIfPresent(RemoteProperty<[Email]?>.self, forKey: .aliases) ?? .unset
		nonEditableAliases = try container.decodeIfPresent(RemoteProperty<[Email]?>.self, forKey: .nonEditableAliases) ?? .unset
		includeInGlobalAddressList = try container.decodeIfPresent(RemoteProperty<Bool>.self, forKey: .includeInGlobalAddressList) ?? .unset
		
		isAdmin = try container.decodeIfPresent(RemoteProperty<Bool>.self, forKey: .isAdmin) ?? .unset
		isDelegatedAdmin = try container.decodeIfPresent(RemoteProperty<Bool>.self, forKey: .isDelegatedAdmin) ?? .unset
		
		lastLoginTime = try container.decodeIfPresent(RemoteProperty<Date?>.self, forKey: .lastLoginTime) ?? .unset
		creationTime = try container.decodeIfPresent(RemoteProperty<Date>.self, forKey: .creationTime) ?? .unset
		agreedToTerms = try container.decodeIfPresent(RemoteProperty<Bool>.self, forKey: .agreedToTerms) ?? .unset
		
		suspended = try container.decodeIfPresent(RemoteProperty<Bool>.self, forKey: .suspended) ?? .unset
		hashFunction = try container.decodeIfPresent(RemoteProperty<PasswordHashFunction?>.self, forKey: .hashFunction) ?? .unset
		password = try container.decodeIfPresent(RemoteProperty<String?>.self, forKey: .password) ?? .unset
		changePasswordAtNextLogin = try container.decodeIfPresent(RemoteProperty<Bool>.self, forKey: .changePasswordAtNextLogin) ?? .unset
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(kind, forKey: .kind)
		try container.encodeIfSet(etag, forKey: .etag)
		
		try container.encodeIfSet(id, forKey: .id)
		try container.encodeIfSet(customerId, forKey: .customerId)
		
		try container.encodeIfSet(name, forKey: .name)
		
		try container.encode(primaryEmail, forKey: .primaryEmail)
		try container.encodeIfSet(aliases, forKey: .aliases)
		try container.encodeIfSet(nonEditableAliases, forKey: .nonEditableAliases)
		try container.encodeIfSet(includeInGlobalAddressList, forKey: .includeInGlobalAddressList)
		
		try container.encodeIfSet(isAdmin, forKey: .isAdmin)
		try container.encodeIfSet(isDelegatedAdmin, forKey: .isDelegatedAdmin)
		
		try container.encodeIfSet(lastLoginTime, forKey: .lastLoginTime)
		try container.encodeIfSet(creationTime, forKey: .creationTime)
		try container.encodeIfSet(agreedToTerms, forKey: .agreedToTerms)
		
		try container.encodeIfSet(suspended, forKey: .suspended)
		try container.encodeIfSet(hashFunction, forKey: .hashFunction)
		try container.encodeIfSet(password, forKey: .password)
		try container.encodeIfSet(changePasswordAtNextLogin, forKey: .changePasswordAtNextLogin)
	}
	
	public var kind: Kind = .user
	public var etag: RemoteProperty<String?> = .unset
	
	public var id: RemoteProperty<String> = .unset
	public var customerId: RemoteProperty<String> = .unset
	
	public var name: RemoteProperty<Name> = .unset
	
	public var primaryEmail: Email
	public var aliases: RemoteProperty<[Email]?> = .unset
	public var nonEditableAliases: RemoteProperty<[Email]?> = .unset
	public var includeInGlobalAddressList: RemoteProperty<Bool> = .unset
	
	public var isAdmin: RemoteProperty<Bool> = .unset
	public var isDelegatedAdmin: RemoteProperty<Bool> = .unset
	
	public var lastLoginTime: RemoteProperty<Date?> = .unset
	public var creationTime: RemoteProperty<Date> = .unset
	public var agreedToTerms: RemoteProperty<Bool> = .unset
	
	public var suspended: RemoteProperty<Bool> = .unset
	public var hashFunction: RemoteProperty<PasswordHashFunction?> = .unset
	public var password: RemoteProperty<String?> = .unset
	public var changePasswordAtNextLogin: RemoteProperty<Bool> = .unset
	
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
		case id, customerId
		case name
		case primaryEmail, aliases, nonEditableAliases, includeInGlobalAddressList
		case isAdmin, isDelegatedAdmin
		case lastLoginTime, creationTime, agreedToTerms
		case suspended, hashFunction, password, changePasswordAtNextLogin
	}
	
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
	
	public var identifyingEmail: RemoteProperty<Email?> {
		return .set(primaryEmail)
	}
	
	public var otherEmails: RemoteProperty<[Email]> {
		return aliases.map{ $0 ?? [] }
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
