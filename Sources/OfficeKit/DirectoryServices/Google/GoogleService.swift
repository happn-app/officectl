/*
 * GoogleService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Async
import GenericJSON
import SemiSingleton
import Service



public final class GoogleService : DirectoryService {
	
	public static let providerId = "internal_google"
	
	public enum UserIdConversionError : Error {
		
		case noEmailInLDAP
		case multipleEmailInLDAP
		
		case tooManyUsersFound
		case unsupportedServiceUserIdConversion
		
		case internalError
		
	}
	
	public typealias ConfigType = GoogleServiceConfig
	public typealias UserType = GoogleUser
	
	public let config: GoogleServiceConfig
	
	public init(config c: GoogleServiceConfig) {
		config = c
	}
	
	public func string(fromUserId userId: Email) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> Email {
		guard let e = Email(string: string) else {
			throw InvalidArgumentError(message: "The given string is not a valid email: \(string)")
		}
		return e
	}
	
	public func shortDescription(from user: GoogleUser) -> String {
		return user.primaryEmail.stringValue
	}
	
	public func exportableJSON(from user: GoogleUser) throws -> JSON {
		return try JSON(encodable: user)
	}
	
	public func logicalUser(fromPersistentId pId: String, hints: [DirectoryUserProperty : Any]) throws -> GoogleUser {
		throw NotSupportedError(message: "It is not possible to create a Google user from its persistent id without fetching it.")
	}
	
	public func logicalUser(fromUserId uId: Email, hints: [DirectoryUserProperty : Any]) throws -> GoogleUser {
		return GoogleUser(email: uId, hints: hints)
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any]) throws -> GoogleUser {
		return try logicalUser(fromUserId: email, hints: hints)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any]) throws -> GoogleUser {
		if service.config.serviceId == config.serviceId, let user: UserType = user.unboxed() {
			/* The given user is already from our service; let’s return it. */
			return user
		}
		
		/* External Directory Service */
		if let (service, user) = try dsuPairFrom(service: service, user: user) as DSUPair<ExternalDirectoryServiceV1>? {
			if let userId = service.userId(fromGenericUserId: user.userId, for: self) {
				return try logicalUser(fromUserId: userId, hints: hints)
			}
			if let userId = service.logicalUserId(fromGenericUserId: user.userId, for: self) {
				return try logicalUser(fromUserId: userId, hints: hints)
			}
			throw NotImplementedError()
		}
		/* GitHub */
		if let (_, _) = try dsuPairFrom(service: service, user: user) as DSUPair<GitHubService>? {
			throw NotImplementedError()
		}
		/* Google (but not myself) */
		if let (_, _) = try dsuPairFrom(service: service, user: user) as DSUPair<GoogleService>? {
			throw NotImplementedError()
		}
		/* LDAP */
		if let (_, _) = try dsuPairFrom(service: service, user: user) as DSUPair<LDAPService>? {
			throw NotImplementedError()
		}
		/* Open Directory */
		if let (_, _) = try dsuPairFrom(service: service, user: user) as DSUPair<OpenDirectoryService>? {
			throw NotImplementedError()
		}
		
		throw NotImplementedError()
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
		return try existingUser(fromEmail: uId, propertiesToFetch: propertiesToFetch, on: container)
	}
	
	public func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
		#warning("TODO: Implement propertiesToFetch")
		/* Note: We do **NOT** map the email to the main domain. Maybe we should? */
		let googleConnector: GoogleJWTConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		let future = googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, eventLoop: container.eventLoop)
		.then{ _ -> Future<[GoogleUser]> in
			let op = SearchGoogleUsersOperation(searchedDomain: email.domain, query: #"email="\#(email.stringValue)""#, googleConnector: googleConnector)
			return Future<[GoogleUser]>.future(from: op, eventLoop: container.eventLoop)
		}
		.thenThrowing{ objects -> GoogleUser? in
			guard objects.count <= 1 else {
				throw UserIdConversionError.tooManyUsersFound
			}
			return objects.first
		}
		return future
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
		if service.config.serviceId == config.serviceId, let user: UserType = user.unboxed() {
			/* The given user is already from our service. */
			return try existingUser(fromUserId: user.userId, propertiesToFetch: propertiesToFetch, on: container)
		}
		
		/* External Directory Service */
		if let (service, user) = try dsuPairFrom(service: service, user: user) as DSUPair<ExternalDirectoryServiceV1>? {
			if let userId = service.userId(fromGenericUserId: user.userId, for: self) {
				return try existingUser(fromUserId: userId, propertiesToFetch: propertiesToFetch, on: container)
			}
			if let userId = service.logicalUserId(fromGenericUserId: user.userId, for: self) {
				return try existingUser(fromUserId: userId, propertiesToFetch: propertiesToFetch, on: container)
			}
			throw NotImplementedError()
		}
		/* GitHub */
		if let (_, _) = try dsuPairFrom(service: service, user: user) as DSUPair<GitHubService>? {
			throw NotImplementedError()
		}
		/* Google (but not myself) */
		if let (_, _) = try dsuPairFrom(service: service, user: user) as DSUPair<GoogleService>? {
			throw NotImplementedError()
		}
		/* LDAP */
		if let (ldapService, ldapUser) = try dsuPairFrom(service: service, user: user) as DSUPair<LDAPService>? {
			return try existingGoogleUser(fromLDAP: ldapUser, ldapService: ldapService, propertiesToFetch: propertiesToFetch, on: container)
		}
		/* Open Directory */
		if let (_, _) = try dsuPairFrom(service: service, user: user) as DSUPair<OpenDirectoryService>? {
			throw NotImplementedError()
		}
		
		throw NotImplementedError()
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[GoogleUser]> {
		let googleConnector: GoogleJWTConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		return googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, eventLoop: container.eventLoop)
		.then{ _ in
			let futures = self.config.primaryDomains.map{ domain -> Future<[GoogleUser]> in
				let searchOp = SearchGoogleUsersOperation(searchedDomain: domain, query: "isSuspended=false", googleConnector: googleConnector)
				return Future<[GoogleUser]>.future(from: searchOp, eventLoop: container.eventLoop)
			}
			/* Merging all the users from all the domains. */
			return Future.reduce([GoogleUser](), futures, eventLoop: container.eventLoop, +)
		}
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: GoogleUser, on container: Container) throws -> Future<GoogleUser> {
		let googleConnector: GoogleJWTConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		let op = CreateGoogleUserOperation(user: user, connector: googleConnector)
		return googleConnector.connect(scope: CreateGoogleUserOperation.scopes, eventLoop: container.eventLoop)
		.then{ _ in Future<[LDAPObject]>.future(from: op, eventLoop: container.eventLoop) }
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: GoogleUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser> {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: GoogleUser, on container: Container) throws -> Future<Void> {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: GoogleUser, on container: Container) throws -> ResetPasswordAction {
		let semiSingletonStore: SemiSingletonStore = try container.make()
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: googleConnector) as ResetGooglePasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func existingGoogleUser(fromLDAP ldapUser: LDAPService.UserType, ldapService: LDAPService, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
		let future = try ldapService.fetchUniqueEmails(from: ldapUser, on: container).map{ emails in
			guard emails.count <= 1 else {throw UserIdConversionError.multipleEmailInLDAP}
			guard let email = emails.first else {throw UserIdConversionError.noEmailInLDAP}
			return email
		}
		.flatMap{ (email: Email) -> Future<GoogleUser?> in
			return try self.existingUser(fromEmail: email, propertiesToFetch: propertiesToFetch, on: container)
		}
		return future
	}
	
}
