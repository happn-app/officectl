/*
 * User.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/12.
 */

import Foundation

import Email
import OfficeModelCore



public protocol User<UserIDType> : Sendable {
	
	associatedtype UserIDType : Hashable & Sendable
	associatedtype PersistentUserIDType : Hashable & Sendable
	
	/**
	 NON-Optional because even for locally created user, the ID must be _decided_.
	 This property does not represent an arbitrary db primary key, it is the ID given to the user.
	 For instance, for an LDAP directory, this would be the distinguished name, which is _not_ random.
	 The db primary key (if any, LDAP does not have one by default) would be stored in the persistentID property. */
	var oU_id: UserIDType {get}
	var oU_persistentID: PersistentUserIDType? {get}
	
	var oU_firstName: String? {get}
	var oU_lastName: String? {get}
	var oU_nickname: String? {get}
	
	var oU_emails: [Email]? {get}
	
	/**
	 The password of the user.
	 
	 You can use this property as a hint when creating a user for his new password.
	 
	 - Important: This property should not be retrieved for an existing user!
	 In theory, for a proper directory, it should not even be possible to retrieve it. */
	var oU_password: String? {get}
	
	func oU_valueForNonStandardProperty(_ property: String) -> Any?
	
}


public extension User {
	
	func valueForProperty(_ property: UserProperty) -> Any? {
		switch property {
			case .id:           return oU_id
			case .persistentID: return oU_persistentID
			case .firstName:    return oU_firstName
			case .lastName:     return oU_lastName
			case .nickname:     return oU_nickname
			case .emails:       return oU_emails
			case .password:     return oU_password
			default:
				assert(!property.isStandard)
				return oU_valueForNonStandardProperty(property.rawValue)
		}
	}
	
}
