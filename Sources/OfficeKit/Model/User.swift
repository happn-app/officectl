/*
 * User.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



/** Represents a user. */
public struct User {
	
	public var id: TaggedId
	public var linkedIds: [TaggedId]
	
	public var firstName: String?
	public var lastName: String?
	
	public var sshKey: String?
	public var password: String?
	
	public init(id userId: TaggedId) {
		id = userId
		linkedIds = []
		
		firstName = nil
		lastName = nil
		
		sshKey = nil
		password = nil
	}
	
	/** Init a user with an “email” id, and fill the distinguished name too. */
	public init(email e: Email, basePeopleDN: LDAPDistinguishedName) {
		#warning("TODO: Review this method…")
		let dn = LDAPDistinguishedName(uid: e.username, baseDN: basePeopleDN)
		
		id = TaggedId(tag: LDAPService.providerId, id: dn.stringValue)
		linkedIds = []
		
		firstName = nil
		lastName = nil
		
		sshKey = nil
		password = nil
	}
	
}


extension User : Hashable {
	
	public static func ==(_ user1: User, _ user2: User) -> Bool {
		return user1.id == user2.id
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
}


extension User : CustomStringConvertible {
	
	public var description: String {
		return (
			"User{mainId=\"\(id)\"" +
			linkedIds.reduce("", { $0 + ",linkedId=\"\($1)\"" }) +
			"}"
		)
	}
	
}
