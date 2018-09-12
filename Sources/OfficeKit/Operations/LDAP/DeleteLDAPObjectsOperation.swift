/*
 * DeleteLDAPObjectsOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/09/2018.
 */

import Foundation

import RetryingOperation

import COpenLDAP



/* Most of this class is adapted from https://github.com/PerfectlySoft/Perfect-LDAP/blob/3ec5155c2a3efa7aa64b66353024ed36ae77349b/Sources/PerfectLDAP/PerfectLDAP.swift */

@available(OSX, deprecated: 10.11) /* See LDAPConnector declaration. The core functionalities of this class will have to be rewritten for the OpenDirectory connector if we ever create it. */
public class DeleteLDAPObjectsOperation : RetryingOperation {
	
	public let connector: LDAPConnector
	
	public let objects: [LDAPObject]
	public private(set) var errors = [Error?]()
	
	public convenience init(users: [LDAPInetOrgPerson], connector c: LDAPConnector) {
		self.init(objects: users.map{ $0.ldapObject() }, connector: c)
	}
	
	public init(objects o: [LDAPObject], connector c: LDAPConnector) {
		objects = o
		connector = c
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(connector.isConnected)
		
		for object in objects {
			/* TODO: Check we do not leak. We should not, though. */
			let r = ldap_delete_ext_s(connector.ldapPtr, object.distinguishedName, nil /* Server controls */, nil /* Client controls */)
			if r == LDAP_SUCCESS {errors.append(nil)}
			else                 {errors.append(NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))]))}
		}
		
		baseOperationEnded()
	}
	
}
