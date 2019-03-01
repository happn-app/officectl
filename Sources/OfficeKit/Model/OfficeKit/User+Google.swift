/*
 * User+Google.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/09/2018.
 */

import Foundation



extension User {
	
	public init(googleUser: GoogleUser, baseDN: LDAPDistinguishedName? = nil) {
		id = .googleUserId(googleUser.id)
		
		distinguishedName = baseDN.flatMap{ LDAPDistinguishedName(uid: googleUser.primaryEmail.username, baseDN: $0 ) }
		googleUserId = googleUser.id
		gitHubId = nil
		email = googleUser.primaryEmail
		
		firstName = googleUser.name.givenName
		lastName = googleUser.name.familyName
		
		sshKey = nil
		password = nil
	}
	
}
