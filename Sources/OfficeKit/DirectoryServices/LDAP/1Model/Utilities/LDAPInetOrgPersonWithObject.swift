/*
 * LDAPInetOrgPersonWithObject.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



/* inetOrgPerson and object are immutable in order to make sure that both are
 * representing the same thing, and one have not been modified with the other
 * being modified.
 * Note however that inetOrgPerson is a class and not a struct, so it can be
 * modified anyway, which is annoying… To fix this, all properties of the
 * LDAPInetOrgPerson class and parents should be lets instead of vars, and
 * modification of these properties would be done by copying the object around
 * (basically reimplementing a struct manually).
 * LDAPInetOrgPerson has to be a class instead of a struct because it is part of
 * a whole object hierarchy that mirrors LDAP’s hierarchy. */
public struct LDAPInetOrgPersonWithObject {
	
	let inetOrgPerson: LDAPInetOrgPerson
	let object: LDAPObject
	
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
	public typealias PersistentIdType = LDAPDistinguishedName
	
	public var userId: LDAPDistinguishedName {
		return inetOrgPerson.dn
	}
	
	public var persistentId: RemoteProperty<LDAPDistinguishedName> {
		#warning("TODO (LDAP does not have a built-in persistent id. We must define the property that is used for this in the config.)")
		return .unsupported
	}
	
	public var emails: RemoteProperty<[Email]> {
		if let e = inetOrgPerson.mail {
			return .set(e)
		}
		return .unset
	}
	
	public var firstName: RemoteProperty<String?> {
		if let e = inetOrgPerson.givenName {
			return .set(e.first)
		}
		return .unset
	}
	
	public var lastName: RemoteProperty<String?> {
		return .set(inetOrgPerson.sn.first)
	}
	
	public var nickname: RemoteProperty<String?> {
		return .unsupported
	}
	
}
