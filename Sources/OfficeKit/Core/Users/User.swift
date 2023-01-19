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
	 The db primary key (if any, LDAP does not have one by default for instance) would be stored in the persistentID property. */
	var oU_id: UserIDType {get}
	var oU_persistentID: PersistentUserIDType? {get}
	
	var oU_isSuspended: Bool? {get}
	
	var oU_firstName: String? {get}
	var oU_lastName: String? {get}
	var oU_nickname: String? {get}
	
	var oU_emails: [Email]? {get}
	
	/**
	 Return here the non-standard properties that can be exposed.
	 
	 Some non-standard properties are for internal use only (e.g. happn’s password property),
	  and some other can and should be public (e.g. a custom property in LDAP).
	 
	 Only the public non-standard properties should be returned here. */
	var oU_nonStandardProperties: Set<String> {get}
	
	func oU_valueForNonStandardProperty(_ property: String) -> (any Sendable)?
	/** When setting to `nil`, the property should be removed if possible (otherwise set to `nil`). */
	mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult
	
}
