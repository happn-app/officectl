/*
 * User.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



/** Represents a user. */
public struct User {
	
	public enum Error : Swift.Error {
		
		case userNotFound
		case tooManyUsersFound
		
		case passwordIsEmpty
		
	}
	
	public var id: UserId
	public var distinguishedName: LDAPDistinguishedName?
	public var googleUserId: String?
	public var gitHubId: String?
	public var email: Email?
	
	public var firstName: String?
	public var lastName: String?
	
	public var sshKey: String?
	public var password: String?
	
	public init(id userId: UserId) {
		id = userId
		
		distinguishedName = userId.distinguishedName
		googleUserId = userId.googleUserId
		gitHubId = userId.gitHubId
		email = userId.email
		
		firstName = nil
		lastName = nil
		
		sshKey = nil
		password = nil
	}
	
	/** Init a user with an “email” id, and fill the distinguished name too. */
	public init(email e: Email, basePeopleDN: LDAPDistinguishedName) {
		id = .email(e)
		
		distinguishedName = LDAPDistinguishedName(uid: e.username, baseDN: basePeopleDN)
		googleUserId = nil
		gitHubId = nil
		email = e
		
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
		var ret = "User{id=\(id)"
		if let dn = distinguishedName, id.distinguishedName == nil {
			ret += ", dn=\(dn)"
		}
		if let guid = googleUserId, id.googleUserId == nil {
			ret += ", guid=\(guid)"
		}
		if let ghid = gitHubId, id.gitHubId == nil {
			ret += ", ghid=\(ghid)"
		}
		if let email = email, id.email == nil {
			ret += ", email=\(email)"
		}
		ret += "}"
		return ret
	}
	
}
