/*
 * HappnUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



public struct HappnUser : Hashable {
	
	public enum Error : Swift.Error {
		
		case operationIsAlreadyExecuting
		case userNotFound
		case tooManyUsersFound
		case passwordIsEmpty
		
	}
	
	public var email: Email
	
	public var firstName: String?
	public var lastName: String?
	
	public var password: String?
	
	public var ldapDN: String?
	public var googleUserId: String?
	public var sshKey: String?
	public var gitHubId: String?
	
	public init(email e: Email) {
		email = e
		
		firstName = nil
		lastName = nil
		
		password = nil
		
		ldapDN = nil
		googleUserId = nil
		sshKey = nil
		gitHubId = nil
	}
	
	public static func ==(_ user1: HappnUser, _ user2: HappnUser) -> Bool {
		return user1.email == user2.email
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(email)
	}
	
}
