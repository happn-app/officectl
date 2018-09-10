/*
 * HappnUser+LDAP.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/09/2018.
 */

import Foundation

import SemiSingleton
import Vapor



extension HappnUser {
	
	public init?(ldapInetOrgPerson: LDAPInetOrgPerson) {
		guard let m = ldapInetOrgPerson.mail?.first, let f = ldapInetOrgPerson.givenName?.first, let l = ldapInetOrgPerson.sn.first else {return nil}
		email = m
		
		firstName = f
		lastName = l
		
		password = ldapInetOrgPerson.userPassword
		
		ldapDN = nil
		sshKey = nil
		googleUserId = nil
		gitHubId = nil
	}
	
	public func checkLDAPPassword(container: Container, checkedPassword: String) throws -> Future<Void> {
		guard !checkedPassword.isEmpty else {throw Error.passwordIsEmpty}
		
		let asyncConfig = try container.make(AsyncConfig.self)
		var ldapConnectorConfig = try container.make(LDAPConnector.Settings.self)
		ldapConnectorConfig.authMode = .userPass(username: LDAPDistinguishedName(email: email.happnComVariant()).stringValue, password: checkedPassword)
		let connector = try LDAPConnector(key: ldapConnectorConfig)
		return connector.connect(scope: (), forceIfAlreadyConnected: true, asyncConfig: asyncConfig)
	}
	
	public func existingLDAPUser(container: Container, attributesToFetch: [String] = ["objectClass", "sn", "cn"]) throws -> Future<LDAPInetOrgPerson> {
		let asyncConfig = try container.make(AsyncConfig.self)
		let semiSingletonStore = try container.make(SemiSingletonStore.self)
		let ldapConnectorConfig = try container.make(LDAPConnector.Settings.self)
		let ldapConnector: LDAPConnector = try semiSingletonStore.semiSingleton(forKey: ldapConnectorConfig)
		
		let searchedDN = LDAPDistinguishedName(email: email.happnComVariant())
		let searchBase = searchedDN.relativeDistinguishedName(for: "dc").stringValue
		let searchQuery = LDAPSearchQuery.simple(attribute: LDAPAttributeDescription(stringOid: "uid")!, filtertype: .equal, value: Data(self.email.username.utf8))
		
		let future = ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[LDAPObject]> in
			let op = LDAPSearchOperation(ldapConnector: ldapConnector, request: LDAPRequest(scope: .children, base: searchBase, searchQuery: searchQuery, attributesToFetch: attributesToFetch))
			return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue, resultRetriever: { op in
				try print(op.results.successValueOrThrow().results)
				return try op.results.successValueOrThrow().results
			})
		}
		.thenThrowing{ objects -> LDAPInetOrgPerson in
			guard objects.count <= 1 else {
				throw Error.tooManyUsersFound
			}
			guard let inetOrgPerson = objects.first?.inetOrgPerson else {
				throw Error.userNotFound
			}
			return inetOrgPerson
		}
		return future
	}
	
	@available(*, deprecated)
	public func ldapInetOrgPerson(baseDN: String) -> LDAPInetOrgPerson {
		let ret = LDAPInetOrgPerson(dn: "uid=" + email.username + ",ou=people," + baseDN, sn: [lastName ?? "<Unknown>"], cn: [(firstName ?? "<Unknown>") + " " + (lastName ?? "<Unknown>")])
		ret.givenName = [firstName ?? "<Unknown>"]
		ret.mail = [email]
		ret.uid = email.username
		ret.userPassword = password
		return ret
	}
	
}
