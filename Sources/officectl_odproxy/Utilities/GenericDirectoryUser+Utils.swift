/*
 * GenericDirectoryUser+Utils.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 18/07/2019.
 */

import Foundation

import OfficeKit



extension GenericDirectoryUser {
	
	init(recordWrapper: ODRecordOKWrapper) throws {
		self.init(userId: .native(.string(recordWrapper.userId.stringValue)))
		#warning("TODO: Fill in the rest?")
	}
	
}
