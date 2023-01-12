/*
 * LDAPObject+Search.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/07.
 */

import Foundation

import COpenLDAP

import OfficeKit



internal extension LDAPObject {
	
	func create(connector: LDAPConnector) async throws -> LDAPObject {
		return try await connector.performLDAPCommunication{ ldapPtr in
			/* TODO: Check we do not leak. We should not, though. */
			var ldapModifsRequest = record.map{ kv -> UnsafeMutablePointer<LDAPMod>? in
				CBridge.ldapModAlloc(method: LDAP_MOD_ADD | LDAP_MOD_BVALUES, key: kv.key.rawValue, values: kv.value)
			} + [nil]
			defer {ldap_mods_free(&ldapModifsRequest, 0)}
			
			/* We use the synchronous version of the function.
			 * See long comment in search operation for details. */
			let r = ldap_add_ext_s(ldapPtr, id.stringValue, &ldapModifsRequest, nil/* Server controls */, nil/* Client controls */)
			guard r == LDAP_SUCCESS else {
				throw OpenLDAPError(code: r)
			}
			
			return self
		}
	}
	
}
