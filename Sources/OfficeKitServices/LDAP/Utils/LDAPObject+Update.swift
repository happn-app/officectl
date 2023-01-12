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
	
	func update(properties: Set<LDAPObjectID>, connector: LDAPConnector) async throws -> LDAPObject {
		return try await connector.performLDAPCommunication{ ldapPtr in
			/* TODO: Check we do not leak. We should not, though. */
			var ldapModifsRequest = properties
				.map{ oid -> UnsafeMutablePointer<LDAPMod>? in
					if let v = record[oid] {
						return CBridge.ldapModAlloc(method: LDAP_MOD_REPLACE | LDAP_MOD_BVALUES, key: oid.rawValue, values: v)
					} else {
						/* NOTE: If the key does not exist on the server, the server will probably return an error.
						 *       From <https://www.ibm.com/docs/en/i/7.2?topic=ssw_ibm_i_72/apis/ldap_modify.htm>. */
						return CBridge.ldapModAlloc(method: LDAP_MOD_DELETE | LDAP_MOD_BVALUES, key: oid.rawValue, values: nil)
					}
				} + [nil]
			defer {ldap_mods_free(&ldapModifsRequest, 0)}
			
			/* We use the synchronous version of the function.
			 * See long comment in search operation for details. */
			let r = ldap_modify_ext_s(ldapPtr, id.stringValue, &ldapModifsRequest, nil/* Server controls */, nil/* Client controls */)
			guard r == LDAP_SUCCESS else {
				throw OpenLDAPError(code: r)
			}
			
			return self
		}
	}
	
	func updatePassword(_ newPassword: String, connector: LDAPConnector) async throws {
		return try await connector.performLDAPCommunication{ ldapPtr in
			/* Let’s build the password change request. */
			guard let ber = ber_alloc_t(LBER_USE_DER) else {
				throw Err.internalError /* Cannot allocate memory. */
			}
			defer {ber_free(ber, 1/* 1 is for “also free buffer” (if I understand correctly). */)}
			
			var bv = berval(bv_len: 0, bv_val: nil)
			try CBridge.buildBervalPasswordChangeRequest(dn: id.stringValue, newPass: newPassword, ber: ber, berval: &bv)
			assert(bv.bv_val != nil)
			
			/* Debug the generated berval data. */
//			var data = Data()
//			for i in 0..<bv.bv_len {data.append(UInt8((Int(bv.bv_val.advanced(by: Int(i)).pointee) + 256) % 256))}
//			Conf.logger?.debug(data.reduce("", { $0 + String(format: "%02x", $1) }))
			
			/* We use the synchronous version of the function.
			 * See long comment in search operation for details. */
			let r = ldap_extended_operation_s(ldapPtr, LDAP_EXOP_MODIFY_PASSWD, &bv, nil/* Server controls */, nil/* Client controls */, nil, nil)
			guard r == LDAP_SUCCESS else {
				throw OpenLDAPError(code: r)
			}
		}
	}
	
}
