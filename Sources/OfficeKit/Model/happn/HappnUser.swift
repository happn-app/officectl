/*
 * HappnUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



public struct HappnUser : Hashable {
	
	public var uid: String
	public var email: Email
	
	public var firstName: String
	public var lastName: String
	
	public var password: String?
	
	public var ldapDN: String?
	public var googleUserId: String?
	public var sshKey: String?
	public var gitHubId: String?
	
	public init(uid id: String, email e: Email, firstName fn: String, lastName ln: String) {
		uid = id
		email = e
		firstName = fn
		lastName = ln
		ldapDN = nil
		googleUserId = nil
		sshKey = nil
		gitHubId = nil
	}
	
	public init(googleUser: GoogleUser) {
		uid = googleUser.primaryEmail.username
		email = googleUser.primaryEmail
		
		firstName = googleUser.name.givenName
		lastName = googleUser.name.familyName
		
		googleUserId = googleUser.id
	}
	
	public init?(ldapInetOrgPerson: LDAPInetOrgPerson) {
		guard let u = ldapInetOrgPerson.uid, let m = ldapInetOrgPerson.mail?.first, let f = ldapInetOrgPerson.givenName?.first, let l = ldapInetOrgPerson.sn.first else {return nil}
		uid = u
		email = m
		
		firstName = f
		lastName = l
		
		password = ldapInetOrgPerson.userPassword
	}
	
	public static func ==(_ user1: HappnUser, _ user2: HappnUser) -> Bool {
		return user1.uid == user2.uid
	}
	
	#if swift(>=4.2)
	public func hash(into hasher: inout Hasher) {
		hasher.combine(uid)
	}
	#else
	public var hashValue: Int {
		return uid.hashValue
	}
	#endif
	
	public func ldapInetOrgPerson(baseDN: String) -> LDAPInetOrgPerson {
		let ret = LDAPInetOrgPerson(dn: "uid=" + uid + ",ou=people," + baseDN, sn: [lastName], cn: [firstName + " " + lastName])
		ret.givenName = [firstName]
		ret.mail = [email]
		ret.uid = uid
		ret.userPassword = password
		return ret
	}
	
}
