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
	
	var oU_id: String
	var oU_persistentID: Never?
	
	var oU_firstName: String?
	var oU_lastName: String?
	var oU_nickname: String?
	
	var oU_emails: [Email]?
	
	func oU_valueForNonStandardProperty(_ property: String) -> Any? {
		return nil
	}
	
}
