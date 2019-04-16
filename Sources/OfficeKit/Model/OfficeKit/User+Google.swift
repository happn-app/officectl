/*
 * User+Google.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/09/2018.
 */

import Foundation

import SemiSingleton
import Vapor



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
	
	public func existingGoogleUser(container: Container) throws -> Future<GoogleUser?> {
		let asyncConfig = try container.make(AsyncConfig.self)
		let semiSingletonStore = try container.make(SemiSingletonStore.self)
		let googleConnectorConfig = try container.make(OfficeKitConfig.self).googleConfigOrThrow().connectorSettings
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: googleConnectorConfig)
		
		#warning("TODO: Fallback to other search terms if the email is not available")
		let searchedEmail = try nil2throw(email, "email")
		
		let future = googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[GoogleUser]> in
			let op = SearchGoogleUsersOperation(searchedDomain: searchedEmail.domain, query: "email=\"\(searchedEmail.stringValue)\"", googleConnector: googleConnector)
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
