/*
 * HappnUserID.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2023/01/17.
 */

import Foundation

import Email



/* About the Codable conformance:
 * For now, we’re codable w/o issues as the HappnUserID value is directly linked to the `login` key.
 * Later, if there is support for LDAP-connect (or other) in the happn API, we might have to use some other keys (most likely `social_synchronization`) to get the HappnUserID.
 * In order to do this, we’ll probably have to remove HappnUserID’s conformance to Codable and do the decoding manually in HappnUser. */
public enum HappnUserID : Hashable, Codable, Sendable, CustomStringConvertible {
	
	/**
	 Case where the login field in the user is `null` (aka `nil`, in Swift) and the login is the primary key.
	 
	 Yes, it is possible to have a `null` login for a happn admin…
	 This currently only happ(e)ns in preprod, for the first admin (Whoozer).
	 
	 An important point to consider: happn allowing null IDs mean the UserID of the HappnService is not (cannot be) a true primary key.
	 In practice, it works because there is only one (admin) user with a `nil` login.
	 
	 Note however that almost all non-admin users in the db have a `nil` login (signed up via Sign in with Apple, etc.). */
	case nullLogin
	/* AFAIK (non-`nil`) logins are always email.
	 * I tried creating a user with an invalid email and the API denied the request. */
	case login(Email)
	
	/* Maybe later happn will support LDAP-login or other, and we might have other types of IDs:
	 * e.g. `case ldap(LDAPDistinguishedName)` */
	
	public var email: Email? {
		switch self {
			case .nullLogin:    return nil
			case .login(let l): return l
		}
	}
	
	public var description: String {
		switch self {
			case .nullLogin:    return "null"
			case .login(let l): return l.rawValue
		}
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		if container.decodeNil() {self = .nullLogin}
		else                     {self = try .login(container.decode(Email.self))}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
			case .nullLogin:    try container.encodeNil()
			case .login(let l): try container.encode(l)
		}
	}
	
}


extension KeyedDecodingContainer {
	
	public func decode(_ type: HappnUserID.Type, forKey key: Key) throws -> HappnUserID {
		return try decodeIfPresent(HappnUserID.self, forKey: key) ?? HappnUserID.nullLogin
	}
	
}
