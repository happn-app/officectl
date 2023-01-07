/*
 * LDAPSearchRequest.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2023/01/07.
 */

import Foundation

import COpenLDAP



public struct LDAPSearchRequest : Sendable {
	
	public enum Scope : ber_int_t, Sendable {
		
		/** <https://ldapwiki.com/wiki/BaseObject> */
		case base = 0
		/** <https://ldapwiki.com/wiki/SingleLevel> */
		case singleLevel = 1
		/** <https://ldapwiki.com/wiki/WholeSubtree> */
		case subtree = 2
		/** <https://ldapwiki.com/wiki/SubordinateSubtree> */
		case children = 3 /* OpenLDAP Extension */
		case `default` = -1 /* OpenLDAP Extension */
		
	}
	
	public var base: LDAPDistinguishedName
	public var scope: Scope
	public var searchQuery: LDAPSearchQuery?
	
	public var attributesToFetch: Set<String>?
	
	public init(base: LDAPDistinguishedName, scope: Scope, searchQuery: LDAPSearchQuery? = nil, attributesToFetch: Set<String>? = nil) {
		self.base = base
		self.scope = scope
		self.searchQuery = searchQuery
		self.attributesToFetch = attributesToFetch
	}
	
}
