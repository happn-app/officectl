/*
 * User+LDAP.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/09/2018.
 */

import Foundation

import SemiSingleton


#warning("This file should not be needed anymore.")

#if false
extension User {
	
	public func bestLDAPSearchRequest(officeKitConfig: OfficeKitConfig, attributesToFetch: [String]) throws -> LDAPSearchRequest {
		if let dn = distinguishedName {
			return LDAPSearchRequest(scope: .base, base: dn, searchQuery: nil, attributesToFetch: attributesToFetch)
		}
		if let email = email {
			let mainDomain = officeKitConfig.mainDomain(for: email.domain)
			let domains = officeKitConfig.equivalentDomains(for: email.domain)
			let emails = domains.map{ Email(email, newDomain: $0) }
			let query = LDAPSearchQuery.or(emails.map{ LDAPSearchQuery.simple(attribute: .mail, filtertype: .equal, value: Data($0.stringValue.utf8)) })
			return LDAPSearchRequest(scope: .children, base: LDAPDistinguishedName(domain: mainDomain), searchQuery: query, attributesToFetch: attributesToFetch)
		}
		throw InvalidArgumentError(message: "Cannot find an LDAP query to fetch user with id “\(id)”")
	}
	
}
#endif
