/*
 * User+LDAP.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/09/2018.
 */

import Foundation

import SemiSingleton
import Vapor


#warning("This file should not be needed anymore.")

#if false
extension User {
	
	public init?(ldapInetOrgPersonWithObject p: LDAPInetOrgPersonWithObject) {
		self.init(ldapInetOrgPerson: p.inetOrgPerson)
		
		sshKey = p.object.firstStringValue(for: "sshPublicKey")
	}
	
	public init?(ldapInetOrgPerson: LDAPInetOrgPerson) {
		guard let dn = try? LDAPDistinguishedName(string: ldapInetOrgPerson.dn), let f = ldapInetOrgPerson.givenName?.first, let l = ldapInetOrgPerson.sn.first else {return nil}
		id = .distinguishedName(dn)
		
		distinguishedName = dn
		googleUserId = nil
		gitHubId = nil
		email = ldapInetOrgPerson.mail?.first
		
		firstName = f
		lastName = l
		
		sshKey = nil
		password = ldapInetOrgPerson.userPassword
	}
	
	public func distinguishedNameIdVariant() -> User? {
		guard let dn = distinguishedName else {return nil}
		
		var ret = self
		ret.id = .distinguishedName(dn)
		return ret
	}
	
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
	
	/* Returns nil if the user was not found but there was no error processing
	 * the request. */
	public func existingLDAPUser(container: Container, attributesToFetch: [String] = ["objectClass", "sn", "cn"]) throws -> Future<LDAPInetOrgPersonWithObject?> {
		let asyncConfig = try container.make(AsyncConfig.self)
		let officeKitConfig = try container.make(OfficeKitConfig.self)
		let semiSingletonStore = try container.make(SemiSingletonStore.self)
		let ldapConnectorConfig = try officeKitConfig.ldapConfigOrThrow().connectorSettings
		let ldapConnector: LDAPConnector = try semiSingletonStore.semiSingleton(forKey: ldapConnectorConfig)
		
		let searchRequest = try bestLDAPSearchRequest(officeKitConfig: officeKitConfig, attributesToFetch: attributesToFetch)
		
		let future = ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[LDAPInetOrgPersonWithObject]> in
			let op = SearchLDAPOperation(ldapConnector: ldapConnector, request: searchRequest)
			return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue).map{ $0.results.compactMap{ LDAPInetOrgPersonWithObject(object: $0) } }
		}
		.thenThrowing{ objects -> LDAPInetOrgPersonWithObject? in
			guard objects.count <= 1 else {
				throw Error.tooManyUsersFound
			}
			return objects.first
		}
		return future
	}
	
	/**
	Creates an LDAP Inet Org Person from the happn User.
	
	The following properties are migrated:
	- username
	- email
	- firstName
	- lastName
	
	The cn of the returned object is inferred from the first and last name of the
	User. If the first or last name is nil in the User, it will be set to
	"<Unknown>".
	
	No password will be set in the returned object.
	
	- parameter baseDN: The base DN in which the returned user will be. Example:
	`ou=people,dc=example,dc=org`
	
	- throws: If there are no emails in the `User`. */
	public func ldapInetOrgPerson(baseDN: LDAPDistinguishedName) throws -> LDAPInetOrgPerson {
		let e = try nil2throw(email, "email")
		let lastNameNonOptional = (lastName ?? "<Unknown>")
		let firstNameNonOptional = (firstName ?? "<Unknown>")
		let dn = LDAPDistinguishedName(uid: e.username, baseDN: baseDN)
		let ret = LDAPInetOrgPerson(dn: dn.stringValue, sn: [lastNameNonOptional], cn: [firstNameNonOptional + " " + lastNameNonOptional])
		ret.givenName = [firstNameNonOptional]
		ret.uid = e.username
		ret.mail = [e]
		return ret
	}
	
}
#endif
