/*
 * ApiUser+Conveniences.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/30.
 */

import Foundation

import OfficeKit
import OfficeModel



extension ApiDirectoryUser {
	
	init(directoryUserWrapper w: DirectoryUserWrapper) {
		self.init(
			userId: w.userId,
			persistentId: w.persistentId.value,
			identifyingEmail: w.identifyingEmail.value ?? nil,
			otherEmails: w.otherEmails.value,
			firstName: w.firstName.value ?? nil,
			lastName: w.lastName.value ?? nil,
			nickname: w.nickname.value ?? nil,
			underlyingUser: w.underlyingUser
		)
	}
	
}
