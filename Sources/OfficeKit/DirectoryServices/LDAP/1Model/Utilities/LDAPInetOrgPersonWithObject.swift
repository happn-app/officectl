/*
 * LDAPInetOrgPersonWithObject.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



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
	
	public typealias IdType = LDAPDistinguishedName
	
	public var id: LDAPDistinguishedName {
		return inetOrgPerson.dn
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
