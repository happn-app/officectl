/*
 * HappnUser+Google.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/09/2018.
 */

import Foundation



extension HappnUser {
	
	public init(googleUser: GoogleUser) {
		email = googleUser.primaryEmail
		
		firstName = googleUser.name.givenName
		lastName = googleUser.name.familyName
		
		password = nil
		
		ldapDN = nil
		sshKey = nil
		googleUserId = googleUser.id
		gitHubId = nil
	}
	
}
