/*
 * ModifyLDAPPasswordOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/09/2018.
 */

import Foundation

import RetryingOperation

import COpenLDAP



/* Adapted from ldappasswd source code: https://github.com/openldap/openldap/blob/59e9ff6243465640956b58ad1756a3ede53eca7c/clients/tools/ldappasswd.c*/

/* If the LDAPObject does not contain a password, will set to a randomly
generated password. */
public final class ModifyLDAPPasswordsOperation : RetryingOperation {
	
	public let connector: LDAPConnector
	
	public let resets: [(dn: LDAPDistinguishedName, pass: String?)]
	
	/** Keys are distinguished names, values are passwords. Only set for users
	whose password was successfully set. */
	public private(set) var passwords = [LDAPDistinguishedName: String]()
	public private(set) var errors: [Error?]
	
	/** Init with a DNs/passwords array. If the password is nil for a given DN,
	a new auto-generated password will be created. */
	public init(resets r: [(LDAPDistinguishedName, String?)], connector c: LDAPConnector) {
		resets = r
		connector = c
		
		errors = [Error?](repeating: OperationIsNotFinishedError(), count: r.count)
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(connector.isConnected)
		assert(resets.count == errors.count)
		
		for (idx, reset) in resets.enumerated() {
			do {
				let pass = reset.pass ?? generateRandomPassword()
				
				/* Let’s build the password change request */
				guard let ber = ber_alloc_t(LBER_USE_DER) else {
					throw NSError(domain: "com.happn.officectl.lber", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot allocate memory"])
				}
				defer {ber_free(ber, 1 /* 1 is for “also free buffer” (if I understand correctly) */)}
				
				var bv = berval(bv_len: 0, bv_val: nil)
				try buildBervalPasswordChangeRequest(dn: reset.dn.stringValue, newPass: pass, ber: ber, berval: &bv)
				assert(bv.bv_val != nil)
				
				/* Debug the generated berval data. */
//				var data = Data()
//				for i in 0..<bv.bv_len {data.append(UInt8((Int(bv.bv_val.advanced(by: Int(i)).pointee) + 256) % 256))}
//				OfficeKitConfig.logger?.debug(data.reduce("", { $0 + String(format: "%02x", $1) }))
				
				/* We use the synchronous version of the function. See long comment
				 * in search operation for details. */
				let r = connector.performLDAPCommunication{ ldap_extended_operation_s($0, LDAP_EXOP_MODIFY_PASSWD, &bv, nil /* Server controls */, nil /* Client controls */, nil, nil) }
				guard r == LDAP_SUCCESS else {
					throw NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))])
				}
				
				passwords[reset.dn] = pass
				errors[idx] = nil
			} catch {
				errors[idx] = error
				continue
			}
		}
		
		baseOperationEnded()
	}
	
	private func buildBervalPasswordChangeRequest(dn: String, newPass: String, ber: OpaquePointer, berval: inout berval) throws {
		/* Basically what we wanne do is:
		 *    ber_printf(ber, "{tstON}", LDAP_TAG_EXOP_MODIFY_PASSWD_ID, dn, LDAP_TAG_EXOP_MODIFY_PASSWD_NEW, &newPassBER);
		 * But ber_printf is unavailable in Swift! So we build the ber manually…
		 * The resulting bytes we get when building manually have been tested to
		 * be the same that we get when building with ber_printf. */
		
		guard ber_start_seq(ber, LDAP_TAG_MESSAGE) >= 0 else {
			throw NSError(domain: "com.happn.officectl.lber", code: 1, userInfo: [NSLocalizedDescriptionKey: "ber_start_seq returned a value < 0"])
		}
		
		let dnData = Data(dn.utf8)
		let retPassId = dnData.withUnsafeBytes{ (bytes: UnsafeRawBufferPointer) -> Int32 in
			let bytes = bytes.bindMemory(to: Int8.self).baseAddress!
			return ber_put_ostring(ber, bytes, ber_len_t(dnData.count), LDAP_TAG_EXOP_MODIFY_PASSWD_ID)
		}
		guard retPassId >= 0 else {
			throw NSError(domain: "com.happn.officectl.lber", code: 1, userInfo: [NSLocalizedDescriptionKey: "ber_put_ostring returned a value < 0"])
		}
		
		let passData = Data(newPass.utf8)
		let retNewPass = passData.withUnsafeBytes{ (bytes: UnsafeRawBufferPointer) -> Int32 in
			let bytes = bytes.bindMemory(to: Int8.self).baseAddress!
			return ber_put_ostring(ber, bytes, ber_len_t(passData.count), LDAP_TAG_EXOP_MODIFY_PASSWD_NEW)
		}
		guard retNewPass >= 0 else {
			throw NSError(domain: "com.happn.officectl.lber", code: 1, userInfo: [NSLocalizedDescriptionKey: "ber_put_ostring returned a value < 0"])
		}
		
		guard ber_put_seq(ber) >= 0 else {
			throw NSError(domain: "com.happn.officectl.lber", code: 1, userInfo: [NSLocalizedDescriptionKey: "ber_put_seq returned a value < 0"])
		}
		
		guard ber_flatten2(ber, &berval, 0) >= 0 else {
			throw NSError(domain: "com.happn.officectl.lber", code: 1, userInfo: [NSLocalizedDescriptionKey: "ber_flatten2 returned a value < 0"])
		}
	}
	
	private func generateRandomPassword() -> String {
		let length = 13
		let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
		return String((0..<length).map{ _ in chars.randomElement()! })
	}
	
}
