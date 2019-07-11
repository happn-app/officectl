/*
 * LDAPInetOrgPerson.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation



/* https://www.ietf.org/rfc/rfc2798.txt */
public class LDAPInetOrgPerson : LDAPOrganizationalPerson {
	
	public static let propNameUID = "uid"
	public static let propNameGivenName = "givenName"
	public static let propNameMail = "mail"
	
	public var uid: String? /* 0.9.2342.19200300.100.1.1 — The UID of the person */
	
	public var givenName: [String]? /* 2.5.4.42 — The names that are not the surnames of the person */
	
	public var mail: [Email]? /* 0.9.2342.19200300.100.1.3 — The email of the person */
	
	public convenience init?(object: LDAPObject) {
		guard object.stringValues(for: LDAPTop.propNameObjectClass)?.contains("inetOrgPerson") ?? false else {return nil}
		guard let sn = object.stringValues(for: LDAPInetOrgPerson.propNameSN), let cn = object.stringValues(for: LDAPInetOrgPerson.propNameCN) else {return nil}
		
		self.init(dn: object.distinguishedName, sn: sn, cn: cn)
		uid = object.singleStringValue(for: LDAPInetOrgPerson.propNameUID)
		givenName = object.stringValues(for: LDAPInetOrgPerson.propNameGivenName)
		userPassword = object.singleStringValue(for: LDAPInetOrgPerson.propNameUserPassword)
		mail = object.stringValues(for: LDAPInetOrgPerson.propNameMail)?.compactMap{ Email(string: $0) }
	}
	
	public override func ldapObject() -> LDAPObject {
		var ret = super.ldapObject()
		ret.attributes[LDAPTop.propNameObjectClass] = [Data("inetOrgPerson".utf8)] /* We override the superclass’s value because it is implicit. */
		if let gn = givenName {ret.attributes[LDAPInetOrgPerson.propNameGivenName] = gn.map{ Data($0.utf8) }}
		if let m = mail {ret.attributes[LDAPInetOrgPerson.propNameMail] = m.map{ Data($0.stringValue.utf8) }}
		if let u = uid {ret.attributes[LDAPInetOrgPerson.propNameUID] = [Data(u.utf8)]}
		return ret
	}
	
}
