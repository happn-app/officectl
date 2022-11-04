/*
 * DummyUser.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email

import OfficeKit2



struct DummyUser2 : User {
	
	typealias IDType = Never
	typealias PersistentIDType = Never
	
	var id: Never
	var persistentID: Never?
	
	var firstName: String?
	var lastName: String?
	var nickname: String?
	
	var emails: [Email]?
	
	var password: String?
	
	func valueForNonStandardProperty(_ property: String) -> Any? {
		return nil
	}
	
}
