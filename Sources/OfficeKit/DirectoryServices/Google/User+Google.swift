/*
 * User+Google.swift
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
	
	public init(googleUser: GoogleUser, baseDN: LDAPDistinguishedName? = nil) {
		id = .googleUserId(googleUser.id)
		
		distinguishedName = baseDN.flatMap{ LDAPDistinguishedName(uid: googleUser.primaryEmail.username, baseDN: $0 ) }
		googleUserId = googleUser.id
		gitHubId = nil
		email = googleUser.primaryEmail
		
		firstName = googleUser.name.givenName
		lastName = googleUser.name.familyName
		
		sshKey = nil
		password = nil
	}
	
	public func bestGoogleSearchQuery(officeKitConfig: OfficeKitConfig) throws -> (domain: String, query: String) {
		func query(for email: Email) -> (domain: String, query: String) {
			let email = email.primaryDomainVariant(aliasMap: officeKitConfig.domainAliases)
			let emailStr = email.stringValue
			return (email.domain, #"email="\#(emailStr)""#)
		}
		
		if let email = email {
			return query(for: email)
		}
		/* A bit hacky, we convert the DN to an email */
		if let dn = distinguishedName, let uid = dn.uid, let email = Email(username: uid, domain: dn.dc.values.map{ $0.value }.joined(separator: ".")) {
			return query(for: email)
		}
		throw InvalidArgumentError(message: "Cannot find a Google query to fetch user with id “\(id)”")
	}
	
	public func existingGoogleUser(container: Container) throws -> Future<GoogleUser?> {
		let asyncConfig = try container.make(AsyncConfig.self)
		let officeKitConfig = try container.make(OfficeKitConfig.self)
		let semiSingletonStore = try container.make(SemiSingletonStore.self)
		let googleConnectorConfig = try officeKitConfig.googleConfigOrThrow().connectorSettings
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: googleConnectorConfig)
		
		let (searchedDomain, searchQuery) = try bestGoogleSearchQuery(officeKitConfig: officeKitConfig)
		
		let future = googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[GoogleUser]> in
			let op = SearchGoogleUsersOperation(searchedDomain: searchedDomain, query: searchQuery, googleConnector: googleConnector)
			return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue)
		}
		.thenThrowing{ objects -> GoogleUser? in
			guard objects.count <= 1 else {
				throw Error.tooManyUsersFound
			}
			return objects.first
		}
		return future
	}
	
}
#endif
