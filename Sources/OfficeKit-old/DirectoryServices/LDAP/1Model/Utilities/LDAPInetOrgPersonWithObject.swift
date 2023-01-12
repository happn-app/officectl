/*
 * LDAPInetOrgPersonWithObject.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/01.
 */

import Foundation

import Email

import OfficeModel



/* inetOrgPerson and object are immutable in order to make sure that both are representing the same thing, and
 * one have not been modified with the other being modified.
 *
 * Note however that inetOrgPerson is a class and not a struct, so it can be modified anyway, which is annoying…
 * To fix this, all properties of the LDAPInetOrgPerson class and parents should be lets instead of vars, and
 * modification of these properties would be done by copying the object around (basically reimplementing a struct manually).
 * LDAPInetOrgPerson has to be a class instead of a struct because it is part of a whole object hierarchy that mirrors LDAP’s hierarchy. */
public struct LDAPInetOrgPersonWithObject {
	
	public let inetOrgPerson: LDAPInetOrgPerson
	public let object: LDAPObject
	
	public init?(object o: LDAPObject) {
		guard let p = LDAPInetOrgPerson(object: o) else {return nil}
		
		inetOrgPerson = p
		object = o
	}
	
	public init(inetOrgPerson p: LDAPInetOrgPerson) {
		inetOrgPerson = p
		object = p.ldapObject()
	}
	
}


extension LDAPInetOrgPersonWithObject : DirectoryUser {
	
	public typealias IDType = LDAPDistinguishedName
	public typealias PersistentIDType = LDAPDistinguishedName
	
	public var userID: LDAPDistinguishedName {
		return inetOrgPerson.dn
	}
	
	public var remotePersistentID: RemoteProperty<LDAPDistinguishedName> {
		/* TODO: LDAP does not have a built-in persistent ID. We must define the property that is used for this in the config. */
		return .unsupported
	}
	
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {
		if let e = inetOrgPerson.mail {
			return .set(e.first)
		}
		return .unset
	}
	
	public var remoteOtherEmails: RemoteProperty<[Email]> {
		if let e = inetOrgPerson.mail {
			return .set(Array(e.dropFirst()))
		}
		return .unset
	}
	
	public var remoteFirstName: RemoteProperty<String?> {
		if let e = inetOrgPerson.givenName {
			return .set(e.first)
		}
		return .unset
	}
	
	public var remoteLastName: RemoteProperty<String?> {
		return .set(inetOrgPerson.sn.first)
	}
	
	public var remoteNickname: RemoteProperty<String?> {
		return .unsupported
	}
	
}
