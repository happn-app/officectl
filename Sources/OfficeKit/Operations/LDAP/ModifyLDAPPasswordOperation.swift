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
public class ModifyLDAPPasswordsOperation : RetryingOperation {
	
	public let connector: LDAPConnector
	
	public let objects: [LDAPObject]
	
	/** Keys are distinguished names, values are passwords. Only set for users
	whose password was successfully set. */
	public private(set) var passwords = [String: String]()
	public private(set) var errors: [Error?]
	
	/** The users must have the new cleartext password set in the `userPassword`
	property. */
	public convenience init(users: [LDAPInetOrgPerson], connector c: LDAPConnector) {
		self.init(objects: users.map{ $0.ldapObject() }, connector: c)
	}
	
	/** The new password must be in the “userPassword” attribute. */
	public init(objects o: [LDAPObject], connector c: LDAPConnector) {
		objects = o
		connector = c
		
		errors = [Error?](repeating: OperationIsNotFinishedError(), count: o.count)
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(connector.isConnected)
		assert(objects.count == errors.count)
		
		for (idx, object) in objects.enumerated() {
			do {
				let pass = object.firstStringValue(for: "userPassword") ?? generateRandomPassword()
				
				/* Let’s build the password change request */
				guard let ber = ber_alloc_t(LBER_USE_DER) else {
					throw NSError(domain: "com.happn.officectl.lber", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot allocate memory"])
				}
				defer {ber_free(ber, 1 /* 1 is for “also free buffer” (if I understand correctly) */)}
				
				var bv = berval(bv_len: 0, bv_val: nil)
				try buildBervalPasswordChangeRequest(dn: object.distinguishedName, newPass: pass, ber: ber, berval: &bv)
				assert(bv.bv_val != nil)
				
				/* Debug the generated berval data. */
//				var data = Data()
//				for i in 0..<bv.bv_len {data.append(UInt8((Int(bv.bv_val.advanced(by: Int(i)).pointee) + 256) % 256))}
//				print(data.reduce("", { $0 + String(format: "%02x", $1) }))
				
				/* We use the synchronous version of the function. See long comment
				 * in search operation for details. */
				let r = ldap_extended_operation_s(connector.ldapPtr, LDAP_EXOP_MODIFY_PASSWD, &bv, nil /* Server controls */, nil /* Client controls */, nil, nil)
				guard r == LDAP_SUCCESS else {
					throw NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))])
				}
				
				passwords[object.distinguishedName] = pass
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
		let retPassId = dnData.withUnsafeBytes{ bytes in
			ber_put_ostring(ber, bytes, ber_len_t(dnData.count), LDAP_TAG_EXOP_MODIFY_PASSWD_ID)
		}
		guard retPassId >= 0 else {
			throw NSError(domain: "com.happn.officectl.lber", code: 1, userInfo: [NSLocalizedDescriptionKey: "ber_put_ostring returned a value < 0"])
		}
		
		let passData = Data(newPass.utf8)
		let retNewPass = passData.withUnsafeBytes{ bytes in
			ber_put_ostring(ber, bytes, ber_len_t(passData.count), LDAP_TAG_EXOP_MODIFY_PASSWD_NEW)
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
