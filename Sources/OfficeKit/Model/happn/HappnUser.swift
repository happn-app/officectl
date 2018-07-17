/*
 * HappnUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



public struct HappnUser {
	
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
	
}
