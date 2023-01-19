/*
 * DummyUser.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email

import OfficeKit



struct DummyUser2 : User {
	
	typealias UserIDType = Never
	typealias PersistentUserIDType = Never
	
	init(oU_id userID: Never) {
		fatalError()
	}
	
	var oU_id: Never
	var oU_persistentID: Never?
	
	var oU_isSuspended: Bool?
	
	var oU_firstName: String?
	var oU_lastName: String?
	var oU_nickname: String?
	
	var oU_emails: [Email]?
	
	var oU_nonStandardProperties: Set<String> {
		return []
	}
	
	func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		return nil
	}
	
	mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		return .failure(.unsupportedProperty)
	}
	
}
