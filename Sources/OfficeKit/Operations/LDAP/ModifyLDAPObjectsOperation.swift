/*
 * ModifyLDAPObjectOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/09/2018.
 */

import Foundation

import RetryingOperation

import COpenLDAP



/* Most of this class is adapted from https://github.com/PerfectlySoft/Perfect-LDAP/blob/3ec5155c2a3efa7aa64b66353024ed36ae77349b/Sources/PerfectLDAP/PerfectLDAP.swift */

/** Use this class to modify LDAP objects.

- Important: Modifying a user’s password with this method will probably work,
but it is recommended to use the `ModifyLDAPPasswordsOperation` instead because
it uses the extended “modify password” LDAP operation which makes sure the
password is properly hashed in the LDAP db. */
@available(OSX, deprecated: 10.11) /* See LDAPConnector declaration. The core functionalities of this class will have to be rewritten for the OpenDirectory connector if we ever create it. */
public class ModifyLDAPObjectsOperation : RetryingOperation {
	
	public let connector: LDAPConnector
	
	public let objects: [LDAPObject]
	public let propertiesToUpdate: [String]
	public private(set) var errors = [Error?]()
	
	public convenience init(users: [LDAPInetOrgPerson], propertiesToUpdate: [String], connector c: LDAPConnector) {
		self.init(objects: users.map{ $0.ldapObject() }, propertiesToUpdate: propertiesToUpdate, connector: c)
	}
	
	public init(objects o: [LDAPObject], propertiesToUpdate ps: [String], connector c: LDAPConnector) {
		objects = o
		connector = c
		propertiesToUpdate = ps
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(connector.isConnected)
		
		for object in objects {
			/* TODO: Check we do not leak. We should not, though. */
			var ldapModifsRequest = object.attributes.filter{ propertiesToUpdate.contains($0.key) }.map{ v -> UnsafeMutablePointer<LDAPMod>? in ldapModAlloc(method: LDAP_MOD_REPLACE | LDAP_MOD_BVALUES, key: v.key, values: v.value) } + [nil]
			defer {ldap_mods_free(&ldapModifsRequest, 0)}
			
			let r = ldap_modify_ext_s(connector.ldapPtr, object.distinguishedName, &ldapModifsRequest, nil /* Server controls */, nil /* Client controls */)
			if r == LDAP_SUCCESS {errors.append(nil)}
			else                 {errors.append(NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))]))}
		}
		
		baseOperationEnded()
	}
	
}
