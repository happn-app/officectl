/*
 * LDAPInetOrgPersonWithObject.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



public struct LDAPInetOrgPersonWithObject {
	
	var inetOrgPerson: LDAPInetOrgPerson
	var object: LDAPObject
	
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
	
	public typealias UserIdType = LDAPDistinguishedName
	#warning("TODO: Honestly, I don’t know what type the persistent id of an LDAP object is.")
	public typealias PersistentIdType = LDAPDistinguishedName
	
	public var userId: LDAPDistinguishedName {
		return inetOrgPerson.dn
	}
	
	public var persistentId: RemoteProperty<LDAPDistinguishedName> {
		#warning("TODO")
		return .unsupported
	}
	
	public var emails: RemoteProperty<[Email]> {
		if let e = inetOrgPerson.mail {
			return .fetched(e)
		}
		return .unfetched
	}
	
	public var firstName: RemoteProperty<String?> {
		if let e = inetOrgPerson.givenName {
			return .fetched(e.first)
		}
		return .unfetched
	}
	
	public var lastName: RemoteProperty<String?> {
		return .fetched(inetOrgPerson.sn.first)
	}
	
	public var nickname: RemoteProperty<String?> {
		return .unsupported
	}
	
}
