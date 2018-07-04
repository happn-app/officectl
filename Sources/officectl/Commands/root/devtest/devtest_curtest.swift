/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation



class CurTestOperation : CommandOperation {
	
	override func startBaseOperation(isRetry: Bool) {
		let c = LDAPConnector(ldapURL: URL(string: "ldap://vip-ldap.happn.io")!, protocolVersion: .v3/*, username: "cn=admin,dc=happn,dc=com", password: "REDACTED"*/)!
		c.connect(scope: ()){ error in
			guard error == nil else {
				print(error!)
				self.baseOperationEnded()
				return
			}
			
			let searchOp = LDAPSearchOperation(ldapConnector: c, request: LDAPRequest(scope: .children, base: "dc=happn,dc=com", searchFilter: nil, attributesToFetch: nil))
			searchOp.completionBlock = {
				for r in searchOp.results.successValue!.results {
					print(r.distinguishedName)
					print(r.singleStringValue(for: "cn"))
				}
				self.baseOperationEnded()
			}
			searchOp.start()
		}
	}
	
}
