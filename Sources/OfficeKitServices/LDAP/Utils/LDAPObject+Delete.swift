/*
 * LDAPObject+Search.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/07.
 */

import Foundation

import COpenLDAP

import OfficeKit2



internal extension LDAPObject {
	
	func delete(connector: LDAPConnector) async throws {
		return try await connector.performLDAPCommunication{ ldapPtr in
			let r = ldap_delete_ext_s(ldapPtr, id.stringValue, nil /* Server controls */, nil /* Client controls */)
			guard r == LDAP_SUCCESS else {
				throw OpenLDAPError(code: r)
			}
		}
	}
	
}
