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
	
	/**
	 NON-Optional because even for locally creted user, the ID must be _decided_.
	 This property does not represent an arbitrary db primary key, it is the ID given to the user.
	 For instance, for an LDAP directory, this would be the distinguished name, which is _not_ random.
	 The db primary key (if any, LDAP does not have one by default) would be stored in the persistentID property. */
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
	
	func mainEmail(domainMap: [String: String] = [:]) -> Email? {
		return identifyingEmails?.first?.primaryDomainVariant(aliasMap: domainMap)
	}
	
}
