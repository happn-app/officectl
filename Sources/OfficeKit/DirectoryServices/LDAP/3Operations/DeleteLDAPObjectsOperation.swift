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

public final class DeleteLDAPObjectsOperation : RetryingOperation {
	
	public let connector: LDAPConnector
	
	public let objects: [LDAPObject]
	public private(set) var errors: [Error?]
	
	public convenience init(users: [LDAPInetOrgPerson], connector c: LDAPConnector) {
		self.init(objects: users.map{ $0.ldapObject() }, connector: c)
	}
	
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
			/* We use the synchronous version of the function. See long comment in
			 * search operation for details. */
			let r = ldap_delete_ext_s(connector.ldapPtr, object.distinguishedName.stringValue, nil /* Server controls */, nil /* Client controls */)
			if r == LDAP_SUCCESS {errors[idx] = nil}
			else                 {errors[idx] = NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))])}
		}
		
		baseOperationEnded()
	}
	
}
