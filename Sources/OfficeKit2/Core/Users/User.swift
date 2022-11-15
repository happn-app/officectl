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
	 NON-Optional because even for locally created user, the ID must be _decided_.
	 This property does not represent an arbitrary db primary key, it is the ID given to the user.
	 For instance, for an LDAP directory, this would be the distinguished name, which is _not_ random.
	 The db primary key (if any, LDAP does not have one by default) would be stored in the persistentID property. */
	var id: IDType {get}
	var persistentID: PersistentIDType? {get}
	
	var firstName: String? {get}
	var lastName: String? {get}
	var nickname: String? {get}
	
	var emails: [Email]? {get}
	
	/**
	 The password of the user.
	 
	 You can use this property as a hint when creating a user for his new password.
	 
	 - Important: This property should not be retrieved for an existing user!
	 In theory, for a proper directory, it should not even be possible to retrieve it. */
	var password: String? {get}
	
	func valueForNonStandardProperty(_ property: String) -> Any?
	
}


public extension User {
	
	func valueForProperty(_ property: UserProperty) -> Any? {
		switch property {
			case .id:        return id
			case .firstName: return firstName
			case .lastName:  return lastName
			case .nickname:  return nickname
			case .emails:    return emails
			case .password:  return password
			default: return valueForNonStandardProperty(property.rawValue)
		}
	}
	
}
