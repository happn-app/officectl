/*
 * DummyUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email

import OfficeKit2



struct DummyUser1 : User {
	
	
	typealias IDType = Never
	typealias PersistentIDType = Never
	
	var id: Never?
	var persistentID: Never?
	
	var identifyingEmails: [Email]?
	var otherEmails: [Email]?
	var firstName: String?
	var lastName: String?
	var nickname: String?
	
}
