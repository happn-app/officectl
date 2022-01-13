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
	
	init(directoryUserWrapper: DirectoryUserWrapper) {
		self.init(
			serviceID:              directoryUserWrapper.sourceServiceID,
			userID:                 directoryUserWrapper.userID.id,
			remotePersistentID:     directoryUserWrapper.remotePersistentID.map{ $0.id },
			remoteIdentifyingEmail: directoryUserWrapper.remoteIdentifyingEmail,
			remoteOtherEmails:      directoryUserWrapper.remoteOtherEmails,
			remoteFirstName:        directoryUserWrapper.remoteFirstName,
			remoteLastName:         directoryUserWrapper.remoteLastName,
			remoteNickname:         directoryUserWrapper.remoteNickname,
			underlyingUser:         directoryUserWrapper.underlyingUser
		)
	}
	
	init(user: AnyDSUPair) throws {
		try self.init(directoryUserWrapper: user.userWrapper())
	}
	
}
