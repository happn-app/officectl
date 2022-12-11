/*
 * SimpleUser1.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/11/04.
 */

import Foundation

import Email

import OfficeKit2



struct SimpleUser1 : User {
	
	typealias UserIDType = String
	typealias PersistentUserIDType = Never
	
	init(oU_id userID: String) {
		self.oU_id = userID
	}
	
	init(oU_id userID: String, oU_firstName firstName: String?, oU_lastName lastName: String?) {
		self.oU_id = userID
		self.oU_firstName = firstName
		self.oU_lastName = lastName
	}
	
	var oU_id: String
	var oU_persistentID: Never?
	
	var oU_isSuspended: Bool?
	
	var oU_firstName: String?
	var oU_lastName: String?
	var oU_nickname: String?
	
	var oU_emails: [Email]?
	
	func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		return nil
	}
	
	mutating func oU_setValue(_ newValue: Sendable?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes: Bool) -> Bool {
#warning("TODO: The other cases.")
		switch property {
			default: return false
		}
	}
	
}
