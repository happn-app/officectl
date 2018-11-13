/*
 * LDAPObject.swift
 * officectl
 *
 * Created by François Lamboley on 04/07/2018.
 */

import Foundation



/** A generic LDAP object. Contains the dn and the attributes/values of the
object. */
public struct LDAPObject {
	
	public let distinguishedName: String
	public let parsedDistinguishedName: LDAPDistinguishedName?
	public var attributes: [String: [Data]]
	
	public var hasValidDistinguishedName: Bool {
		return parsedDistinguishedName != nil
	}
	
	public init(distinguishedName dn: String, attributes attrs: [String: [Data]]) {
		parsedDistinguishedName = try? LDAPDistinguishedName(string: dn)
		distinguishedName = dn
		attributes = attrs
	}
	
	public func stringValues(for key: String) -> [String]? {
		guard let v = attributes[key] else {return nil}
		return v.compactMap{ String(data: $0, encoding: .utf8) }
	}
	
	/* Return the first value for the given key which has a valid UTF-8 string
	 * representation. */
	public func firstStringValue(for key: String) -> String? {
		return stringValues(for: key)?.first /* This is not very optimized… */
	}
	
	public func singleValue(for key: String) -> Data? {
		guard let a = attributes[key], let f = a.first, a.count == 1 else {return nil}
		return f
	}
	
	public func singleStringValue(for key: String) -> String? {
		return singleValue(for: key).flatMap{ String(data: $0, encoding: .utf8) }
	}
	
	public var inetOrgPerson: LDAPInetOrgPerson? {
		guard stringValues(for: "objectClass")?.contains("inetOrgPerson") ?? false else {return nil}
		guard let sn = stringValues(for: "sn"), let cn = stringValues(for: "cn") else {return nil}
		
		let ret = LDAPInetOrgPerson(dn: distinguishedName, sn: sn, cn: cn)
		ret.uid = singleStringValue(for: "uid")
		ret.givenName = stringValues(for: "givenName")
		ret.userPassword = singleStringValue(for: "userPassword")
		ret.mail = stringValues(for: "mail")?.compactMap{ Email(string: $0) }
		return ret
	}
	
}
