/*
 * UsersController.swift
 * officectl
 *
 * Created by François Lamboley on 01/03/2019.
 */

import Foundation

import GenericJSON
import JWT
import OfficeKit
import SemiSingleton
import Vapor



class UsersController {
	
	func getAllUsers(_ req: Request) throws -> Future<ApiResponse<[ApiUser]>> {
		throw NotImplementedError()
		#if false
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
		let aliases = officeKitConfig.domainAliases
		
		let ldapConfig = try officeKitConfig.ldapConfigOrThrow()
		let ldapConnectorConfig = ldapConfig.connectorSettings
		let ldapConnector: LDAPConnector = try semiSingletonStore.semiSingleton(forKey: ldapConnectorConfig)
		
		let googleConfig = try officeKitConfig.googleConfigOrThrow()
		let googleConnectorConfig = googleConfig.connectorSettings
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: googleConnectorConfig)
		
		return Future<Void>.andAll([
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
				
				user.googleUserId = googleUsers.first(where: { $0.primaryEmail.primaryDomainVariant(aliasMap: aliases) == user.email?.primaryDomainVariant(aliasMap: aliases) })?.id
				return user
			}
			
			return req.future(ApiResponse.data(users))
		}
		#endif
	}
	
	func getMe(_ req: Request) throws -> Future<ApiResponse<ApiUser>> {
		throw NotImplementedError()
	}
	
	func getUser(_ req: Request) throws -> Future<ApiResponse<ApiUser>> {
		/* General auth check */
		let officectlConfig = try req.make(OfficectlConfig.self)
		guard let bearer = req.http.headers.bearerAuthorization else {throw Abort(.unauthorized)}
		let token = try JWT<ApiAuth.Token>(from: bearer.token, verifiedUsing: .hs256(key: officectlConfig.jwtSecret))
		
		/* Parameter retrieval */
		let userId = try req.parameters.next(UserIdParameter.self)
		
		/* Only admins are allowed to see aany user. Other users can only see
		 * themselves. */
		guard try token.payload.adm || token.payload.representsSameUserAs(userId: userId, container: req) else {
			throw Abort(.forbidden)
		}
		
		let sProvider = try req.make(OfficeKitServiceProvider.self)
		let (service, user) = try (userId.service, userId.service.logicalUser(fromUserId: userId.id, hints: [:]))
		
		let allServices = try sProvider.getAllServices(container: req)
		let userFutures = allServices.map{ curService in
			req.future().flatMap{
				try curService.existingUser(from: user, in: service, propertiesToFetch: [], on: req)
			}
		}
		return Future.waitAll(userFutures, eventLoop: req.eventLoop).map{ userResults in
			var serviceIdToUser = [String: ApiResponse<JSON?>]()
			for (idx, userResult) in userResults.enumerated() {
				let service = allServices[idx]
				serviceIdToUser[service.config.serviceId] = ApiResponse(result: userResult.flatMap{ curUser in Result{ try curUser.flatMap{ try service.exportableJSON(from: $0) } } }, environment: req.environment)
			}
			return ApiResponse.data(ApiUser(requestedUserId: userId.taggedId, serviceUsers: serviceIdToUser))
		}
	}
	
}
