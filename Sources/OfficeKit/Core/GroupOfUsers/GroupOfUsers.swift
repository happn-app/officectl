/*
 * GroupOfUsers.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/21.
 */

import Foundation

import Email



public protocol GroupOfUsers : Sendable {
	
	associatedtype GroupOfUsersIDType : Hashable & Sendable
	associatedtype PersistentGroupOfUsersIDType : Hashable & Sendable
	
	/**
	 NON-Optional because even for locally creted group, the ID must be _decided_.
	 This property does not represent an arbitrary db primary key, it is the ID given to the user.
	 For instance, for an LDAP directory, this would be the distinguished name, which is _not_ random.
	 The db primary key (if any, LDAP does not have one by default) would be stored in the persistentID property. */
	var oGOU_id: GroupOfUsersIDType {get}
	var oGOU_persistentID: PersistentGroupOfUsersIDType? {get}
	
	var oGOU_name: String? {get}
	var oGOU_description: String? {get}
	
	var oGOU_emails: [Email] {get}
	
}
