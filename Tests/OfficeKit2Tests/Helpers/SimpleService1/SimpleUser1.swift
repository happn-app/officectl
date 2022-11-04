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
	
	typealias IDType = String
	typealias PersistentIDType = Never
	
	var id: String
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
