/*
 * DummyUser.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email

import OfficeKit2



struct DummyUser1 : User {
	
	typealias UserIDType = Never
	typealias PersistentUserIDType = Never
	
	var oU_id: Never
	var oU_persistentID: Never?
	
	var oU_firstName: String?
	var oU_lastName: String?
	var oU_nickname: String?
	
	var oU_emails: [Email]?
	
	func oU_valueForNonStandardProperty(_ property: String) -> Any? {
		return nil
	}
	
}
