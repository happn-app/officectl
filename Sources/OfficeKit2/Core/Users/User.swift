/*
 * User.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/12.
 */

import Foundation

import Email
import OfficeModelCore



public protocol User<IDType> : Sendable {
	
	associatedtype IDType : Hashable & Sendable
	associatedtype PersistentIDType : Hashable & Sendable
	
	var id: IDType {get}
	var persistentID: PersistentIDType? {get}
	
	var identifyingEmails: [Email]? {get}
	var otherEmails: [Email]? {get}
	
//	var fullName: String? {get}
	var firstName: String? {get}
	var lastName: String? {get}
	var nickname: String? {get}
	
}


public extension User {
	
	var emails: [Email] {
		(identifyingEmails ?? []) + (otherEmails ?? [])
	}
	
}
