/*
 * UsersController.swift
 * officectl
 *
 * Created by François Lamboley on 01/03/2019.
 */

import Foundation

import JWT
import OfficeKit
import SemiSingleton
import Vapor



class UsersController {
	
	func searchUsers(_ req: Request) throws -> Future<ApiResponse<[User]>> {
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Only admins are allowed to search for users. */
		guard token.payload.adm else {
			throw Abort(.forbidden)
		}
		
		throw NotImplementedError()
		/*
		let asyncConfig = try req.make(AsyncConfig.self)
		let officeKitConfig = officectlConfig.officeKitConfig
		let baseDNs = try officeKitConfig.ldapConfigOrThrow().allBaseDNs
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		let ldapConnectorConfig = try officeKitConfig.ldapConfigOrThrow().connectorSettings
		let googleConnectorConfig = try officeKitConfig.googleConfigOrThrow().connectorSettings
		let ldapConnector: LDAPConnector = try semiSingletonStore.semiSingleton(forKey: ldapConnectorConfig)
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: googleConnectorConfig)
		
		#warning("TODO")
//		let googleDomain = try nil2throw(officeKitConfig.googleConfig?.domains.first, "Google Domain in Config")
		let googleDomain = "happn.fr"
		
		return EventLoopFuture<Void>.andAll([
			ldapConnector.connect(scope: (), asyncConfig: asyncConfig),
			googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
		], eventLoop: req.eventLoop)
		.then{ _ in
			let searchLDAPRequest = LDAPSearchRequest(scope: .children, base: baseDN, searchQuery: nil, attributesToFetch: ["objectClass", "uid", "givenName", "mail", "sn", "cn", "sshPublicKey"])
			let searchLDAPOperation = SearchLDAPOperation(ldapConnector: ldapConnector, request: searchLDAPRequest)
			let searchLDAPFuture = req.eventLoop.future(from: searchLDAPOperation, queue: asyncConfig.operationQueue).map{ $0.results.compactMap{ LDAPInetOrgPersonWithObject(object: $0) } }
			
			let searchGoogleOperation = SearchGoogleUsersOperation(searchedDomain: googleDomain, query: "isSuspended=false", googleConnector: googleConnector)
			let searchGoogleFuture = req.eventLoop.future(from: searchGoogleOperation, queue: asyncConfig.operationQueue)
			
			return searchLDAPFuture.and(searchGoogleFuture)
		}
		.then{ (ldapUsers: [LDAPInetOrgPersonWithObject], googleUsers: [GoogleUser]) -> Future<ApiResponse<[User]>> in
			var googleUsers = googleUsers
			
			/* Let’s build the merge of the LDAP and Google users objects. */
			/* First take all LDAP objects and merge w/ Google objects. */
			var users = ldapUsers.compactMap{ ldapObject -> User? in
				guard var user = User(ldapInetOrgPersonWithObject: ldapObject) else {return nil}
				
				user.googleUserId = googleUsers.first(where: { $0.primaryEmail.happnFrVariant() == user.email?.happnFrVariant() })?.id
				googleUsers.removeAll(where: { $0.primaryEmail.happnFrVariant() == user.email?.happnFrVariant() })
				return user
			}
			/* Then add Google objects that were not in LDAP. */
			users += googleUsers.map{ User(googleUser: $0) }
			
			return req.future(ApiResponse.data(users))
		}*/
	}
	
	func getUsers(_ req: Request) throws -> Future<ApiResponse<[User]>> {
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Only admins are allowed to list users. */
		guard token.payload.adm else {
			throw Abort(.forbidden)
		}
		
		let asyncConfig = try req.make(AsyncConfig.self)
		let officeKitConfig = officectlConfig.officeKitConfig
		let semiSingletonStore = try req.make(SemiSingletonStore.self)
		
		let ldapConfig = try officeKitConfig.ldapConfigOrThrow()
		let ldapConnectorConfig = ldapConfig.connectorSettings
		let ldapConnector: LDAPConnector = try semiSingletonStore.semiSingleton(forKey: ldapConnectorConfig)
		
		let googleConfig = try officeKitConfig.googleConfigOrThrow()
		let googleConnectorConfig = googleConfig.connectorSettings
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: googleConnectorConfig)
		
		return EventLoopFuture<Void>.andAll([
			ldapConnector.connect(scope: (), asyncConfig: asyncConfig),
			googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
		], eventLoop: req.eventLoop)
		.then{ _ in
			let searchLDAPOperations = ldapConfig.allBaseDNs
				.map{ LDAPSearchRequest(scope: .children, base: $0, searchQuery: nil, attributesToFetch: ["objectClass", "uid", "givenName", "mail", "sn", "cn", "sshPublicKey"]) }
				.map{ SearchLDAPOperation(ldapConnector: ldapConnector, request: $0) }
			let searchLDAPFutures = searchLDAPOperations
				.map{ req.eventLoop.future(from: $0, queue: asyncConfig.operationQueue).map{ $0.results.compactMap{ LDAPInetOrgPersonWithObject(object: $0) } } }
			let searchLDAPFuture = Future.reduce([], searchLDAPFutures, eventLoop: req.eventLoop, +)
			
			let searchGoogleOperations = googleConfig.primaryDomains.intersection(ldapConfig.allDomains)
				.map{ SearchGoogleUsersOperation(searchedDomain: $0, query: "isSuspended=false", googleConnector: googleConnector) }
			let searchGoogleFutures = searchGoogleOperations
				.map{ req.eventLoop.future(from: $0, queue: asyncConfig.operationQueue) }
			let searchGoogleFuture = Future.reduce([], searchGoogleFutures, eventLoop: req.eventLoop, +)
			
			return searchLDAPFuture.and(searchGoogleFuture)
		}
		.then{ (ldapUsers: [LDAPInetOrgPersonWithObject], googleUsers: [GoogleUser]) -> Future<ApiResponse<[User]>> in
			/* Let’s take all LDAP objects and merge them w/ Google objects. */
			let users = ldapUsers.compactMap{ ldapObject -> User? in
				guard var user = User(ldapInetOrgPersonWithObject: ldapObject) else {return nil}
				
				user.googleUserId = googleUsers.first(where: { $0.primaryEmail.happnFrVariant() == user.email?.happnFrVariant() })?.id
				return user
			}
			
			return req.future(ApiResponse.data(users))
		}
	}
	
	func getUser(_ req: Request) throws -> Future<ApiResponse<User>> {
		let dn = try req.parameters.next(LDAPDistinguishedName.self)
		
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Can only show user if connected user is the same or connected user is admin. */
		guard token.payload.sub == dn.stringValue || token.payload.adm else {
			throw Abort(.forbidden)
		}
		
		var u = User(id: .distinguishedName(dn))
		u.email = try Email(username: nil2throw(dn.uid, "uid in DN"), domain: "happn.fr")
		
		let ldapUserFuture = try u.existingLDAPUser(container: req, attributesToFetch: ["objectClass", "uid", "givenName", "mail", "sn", "cn", "sshPublicKey"])
		let googleUserFuture = try u.existingGoogleUser(container: req)
		
		return ldapUserFuture.and(googleUserFuture)
		.thenThrowing{
			let (inetOrgPerson, googleUser) = $0
			
			let ret: User
			if let inetOrgPerson = inetOrgPerson, var u = User(ldapInetOrgPersonWithObject: inetOrgPerson) {
				u.googleUserId = googleUser?.id
				ret = u
			} else if let googleUser = googleUser {
				ret = User(googleUser: googleUser)
			} else {
				throw Vapor.Abort(.notFound)
			}
			
			return ApiResponse.data(ret)
		}
	}
	
}
