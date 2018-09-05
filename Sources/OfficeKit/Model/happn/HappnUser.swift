/*
 * HappnUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation

import SemiSingleton
import Vapor



public struct HappnUser : Hashable {
	
	public enum Error : Swift.Error {
		
		case operationIsAlreadyExecuting
		case userNotFound
		case tooManyUsersFound
		
	}
	
	public var email: Email
	
	public var firstName: String?
	public var lastName: String?
	
	public var password: String?
	
	public var ldapDN: String?
	public var googleUserId: String?
	public var sshKey: String?
	public var gitHubId: String?
	
	public init(email e: Email) {
		email = e
		firstName = nil
		lastName = nil
		ldapDN = nil
		googleUserId = nil
		sshKey = nil
		gitHubId = nil
	}
	
	public init(googleUser: GoogleUser) {
		email = googleUser.primaryEmail
		
		firstName = googleUser.name.givenName
		lastName = googleUser.name.familyName
		
		googleUserId = googleUser.id
	}
	
	public init?(ldapInetOrgPerson: LDAPInetOrgPerson) {
		guard let m = ldapInetOrgPerson.mail?.first, let f = ldapInetOrgPerson.givenName?.first, let l = ldapInetOrgPerson.sn.first else {return nil}
		email = m
		
		firstName = f
		lastName = l
		
		password = ldapInetOrgPerson.userPassword
	}
	
	public static func ==(_ user1: HappnUser, _ user2: HappnUser) -> Bool {
		return user1.email == user2.email
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(email)
	}
	
	public func checkLDAPPassword(container: Container, checkedPassword: String) throws -> Future<Void> {
		let asyncConfig = try container.make(AsyncConfig.self)
		var ldapConnectorConfig = try container.make(LDAPConnector.Settings.self)
		ldapConnectorConfig.authMode = .userPass(username: LDAPDistinguishedName(email: email.happnComVariant()).stringValue, password: checkedPassword)
		let connector = try LDAPConnector(key: ldapConnectorConfig)
		return connector.connect(scope: (), forceIfAlreadyConnected: true, asyncConfig: asyncConfig)
	}
	
	public func existingLDAPUser(container: Container) throws -> Future<LDAPInetOrgPerson> {
		let asyncConfig = try container.make(AsyncConfig.self)
		let semiSingletonStore = try container.make(SemiSingletonStore.self)
		let ldapConnectorConfig = try container.make(LDAPConnector.Settings.self)
		let ldapConnector: LDAPConnector = try semiSingletonStore.semiSingleton(forKey: ldapConnectorConfig)
		let future = ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[LDAPObject]> in
			let op = LDAPSearchOperation(ldapConnector: ldapConnector, request: LDAPRequest(scope: .children, base: "dc=happn,dc=com", searchFilter: "(uid=" + self.email.username.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ")", with: "\\)") + ")", attributesToFetch: ["userPassword", "objectClass", "sn", "cn"]))
			return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue, resultRetriever: { op in
				return try op.results.successValueOrThrow().results
			})
		}
		.then{ objects -> Future<LDAPInetOrgPerson> in
			guard objects.count <= 1 else {
				return container.future(error: Error.tooManyUsersFound)
			}
			guard let inetOrgPerson = objects.first?.inetOrgPerson else {
				return container.future(error: Error.userNotFound)
			}
			return container.future(inetOrgPerson)
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
