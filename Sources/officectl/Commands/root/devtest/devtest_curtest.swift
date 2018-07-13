/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation

import OfficeKit



class CurTestOperation : CommandOperation {
	
	override func startBaseOperation(isRetry: Bool) {
//		let c = LDAPConnector(ldapURL: URL(string: "ldap://ldap.happn.test")!, protocolVersion: .v3/*, username: "cn=admin,dc=happn,dc=com", password: "REDACTED"*/)!
		let c = LDAPConnector(ldapURL: URL(string: "ldap://vip-ldap.happn.io")!, protocolVersion: .v3/*, username: "cn=admin,dc=happn,dc=com", password: "REDACTED"*/)!
		c.connect(scope: ()){ error in
			guard error == nil else {
				print(error!)
				self.baseOperationEnded()
				return
			}
			
			let searchOp = LDAPSearchOperation(ldapConnector: c, request: LDAPRequest(scope: .children, base: "dc=happn,dc=com", searchFilter: nil, attributesToFetch: nil))
			searchOp.completionBlock = {
				defer {self.baseOperationEnded()}
				guard let v = searchOp.results.successValue else {return}
				for r in v.results.filter({ $0.relativeDistinguishedNameValues(for: "ou") == ["people"] && $0.relativeDistinguishedNameValues(for: "uid") != [] }) {
					print(r.distinguishedName)
//					print(r.singleStringValue(for: "cn"))
//					print(r.attributes.keys)
//					print(r.singleStringValue(for: "uid"))
					print(r.stringValues(for: "objectClass"))
//					print(r)
				}
			}
			searchOp.start()
		}
	}
	
}
