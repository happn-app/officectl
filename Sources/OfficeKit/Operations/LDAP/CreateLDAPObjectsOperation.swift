/*
 * CreateLDAPObjectsOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 19/07/2018.
 */

import Foundation

import RetryingOperation

import COpenLDAP



/* Most of this class is adapted from https://github.com/PerfectlySoft/Perfect-LDAP/blob/3ec5155c2a3efa7aa64b66353024ed36ae77349b/Sources/PerfectLDAP/PerfectLDAP.swift */

/**
Result is an array of LDAPObject (the objects created). The operation as a whole
does not fail from the `HasResult` protocol point of view. If all users failed
to be created, the result will simply be an empty array.

You should access the errors array to get the errors that happened while
creating the objects. There is one optional error per object created. If the
error is nil for a given object, it means the object has successfully been
created, otherwise the error tells you what went wrong. */
@available(OSX, deprecated: 10.11) /* See LDAPConnector declaration. The core functionalities of this class will have to be rewritten for the OpenDirectory connector if we ever create it. */
public class CreateLDAPObjectsOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [LDAPObject]
	
	public let connector: LDAPConnector
	
	public let objects: [LDAPObject]
	public private(set) var errors: [Error?]
	public func resultOrThrow() throws -> [LDAPObject] {
		let successfulCreationsIndexes = errors.enumerated().filter{ $0.element == nil }.map{ $0.offset }
		return successfulCreationsIndexes.map{ objects[$0] }
	}
	
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
			/* TODO: Check we do not leak. We should not, though. */
			var ldapModifsRequest = object.attributes.map{ v -> UnsafeMutablePointer<LDAPMod>? in ldapModAlloc(method: LDAP_MOD_ADD | LDAP_MOD_BVALUES, key: v.key, values: v.value) } + [nil]
			defer {ldap_mods_free(&ldapModifsRequest, 0)}
			
			/* We use the synchronous version of the function. See long comment in
			 * search operation for details. */
			let r = ldap_add_ext_s(connector.ldapPtr, object.distinguishedName, &ldapModifsRequest, nil /* Server controls */, nil /* Client controls */)
			if r == LDAP_SUCCESS {errors[idx] = nil}
			else                 {errors[idx] = NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))])}
		}
		
		baseOperationEnded()
	}
	
}
