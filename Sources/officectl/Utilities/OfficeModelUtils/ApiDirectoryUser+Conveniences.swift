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
			serviceID: w.sourceServiceID,
			userID: w.userID.id,
			remotePersistentID: w.remotePersistentID.map{ $0.id },
			remoteIdentifyingEmail: w.remoteIdentifyingEmail,
			remoteOtherEmails: w.remoteOtherEmails,
			remoteFirstName: w.remoteFirstName,
			remoteLastName: w.remoteLastName,
			remoteNickname: w.remoteNickname,
			underlyingUser: w.underlyingUser
		)
	}
	
}
