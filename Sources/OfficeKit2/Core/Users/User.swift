/*
 * User.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/12.
 */

import Foundation

import Email
import GenericJSON
import OfficeModelCore



public protocol User<UserIDType> : Sendable {
	
	associatedtype UserIDType : Hashable & Sendable
	associatedtype PersistentUserIDType : Hashable & Sendable
	
	init(oU_id userID: UserIDType)
	
	/**
	 NON-Optional because even for locally created user, the ID must be _decided_.
	 This property does not represent an arbitrary db primary key, it is the ID given to the user.
	 For instance, for an LDAP directory, this would be the distinguished name, which is _not_ random.
	 The db primary key (if any, LDAP does not have one by default) would be stored in the persistentID property. */
	var oU_id: UserIDType {get}
	var oU_persistentID: PersistentUserIDType? {get}
	
	var oU_isSuspended: Bool? {get}
	
	var oU_firstName: String? {get}
	var oU_lastName: String? {get}
	var oU_nickname: String? {get}
	
	var oU_emails: [Email]? {get}
	
	func oU_valueForNonStandardProperty(_ property: String) -> (any Sendable)?
	/**
	 When setting to `nil`, the property should be removed.
	 
	 - Returns: `true` if the property was modified, `false` otherwise. */
	mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes: Bool) -> Bool
	
}


public extension User {
	
	func oU_valueForProperty(_ property: UserProperty) -> Any? {
		switch property {
			case .id:           return oU_id
			case .persistentID: return oU_persistentID
			case .isSuspended:  return oU_isSuspended
			case .firstName:    return oU_firstName
			case .lastName:     return oU_lastName
			case .nickname:     return oU_nickname
			case .emails:       return oU_emails
			default:
				assert(!property.isStandard)
				return oU_valueForNonStandardProperty(property.rawValue)
		}
	}
	
	mutating func oU_applyHints(_ hints: [UserProperty: (any Sendable)?], allowIDChange: Bool, convertMismatchingTypes: Bool) -> Set<UserProperty> {
		return Set(hints.compactMap{ kv in
			oU_setValue(kv.value, forProperty: kv.key, allowIDChange: allowIDChange, convertMismatchingTypes: convertMismatchingTypes) ?
				kv.key : nil
		})
	}
	
}
