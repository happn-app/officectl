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
	
	public let distinguishedName: LDAPDistinguishedName
	public var attributes: [String: [Data]]
	
	public init(distinguishedNameString dn: String, attributes attrs: [String: [Data]]) throws {
		distinguishedName = try LDAPDistinguishedName(string: dn)
		attributes = attrs
	}
	
	public init(distinguishedName dn: LDAPDistinguishedName, attributes attrs: [String: [Data]]) {
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
		guard let a = attributes[key], let f = a.onlyElement else {return nil}
		return f
	}
	
	public func singleStringValue(for key: String) -> String? {
		return singleValue(for: key).flatMap{ String(data: $0, encoding: .utf8) }
	}
	
}
