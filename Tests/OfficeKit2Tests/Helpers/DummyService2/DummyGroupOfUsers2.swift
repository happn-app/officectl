/*
 * DummyGroupOfUsers.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email

import OfficeKit2



struct DummyGroupOfUsers2 : GroupOfUsers {
	
	
	typealias IDType = Never
	typealias PersistentIDType = Never
	
	var groupID: Never
	var persistentID: Never?
	
	var identifyingEmails: [Email]?
	var otherEmails: [Email]?
	var name: String?
	var description: String?
	
}
