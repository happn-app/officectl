/*
 * DummyUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email

import OfficeKit2



public struct DummyUser : User {
	
	
	public typealias IDType = Never
	public typealias PersistentIDType = Never
	
	public var id: Never
	public var persistentID: Never?
	
	public var identifyingEmails: [Email]?
	public var otherEmails: [Email]?
	public var firstName: String?
	public var lastName: String?
	public var nickname: String?
	
}
