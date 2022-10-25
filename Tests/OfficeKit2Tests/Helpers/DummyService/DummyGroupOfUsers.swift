/*
 * DummyGroupOfUsers.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email

import OfficeKit2



public struct DummyGroupOfUsers : GroupOfUsers {
	
	
	public typealias IDType = Never
	public typealias PersistentIDType = Never
	
	public var groupID: Never?
	public var persistentID: Never?
	
	public var identifyingEmails: [Email]?
	public var otherEmails: [Email]?
	public var name: String?
	public var description: String?
	
}
