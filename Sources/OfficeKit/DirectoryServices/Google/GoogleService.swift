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
	
	public func shortDescription(from user: GoogleUser) -> String {
		return user.primaryEmail.stringValue
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
	
	public func string(fromPersistentId pId: String) -> String {
		return pId
	}
	
	public func persistentId(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: GoogleUser) throws -> JSON {
		#warning("TODO (Note: Goes with the TODO related to JSONEncoder in logicalUser from wrapped user below.)")
		return try JSON(encodable: user)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> GoogleUser {
		let taggedId = userWrapper.userId
		if taggedId.tag == config.serviceId, let underlying = userWrapper.underlyingUser {
			/* The generic user is from our service! We should be able to translate
			 * if fully to our User type. */
			#warning("TODO: Not elegant. We should do better but I’m lazy rn")
			let encoded = try JSONEncoder().encode(underlying)
			return try JSONDecoder().decode(GoogleUser.self, from: encoded)
			
		} else if taggedId.tag == config.serviceId {
			/* The generic user id from our service, but there is no underlying
			 * user… Let’s create a GoogleUser from the user id. */
			guard let email = Email(string: taggedId.id) else {
				throw InvalidArgumentError(message: "Got an invalid id for a GoogleService user.")
			}
			return GoogleUser(email: email)
			
		} else {
			guard let email = userWrapper.mainEmail(domainMap: config.global.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create a GoogleUser")
			}
			let res = GoogleUser(email: email)
			#warning("Other properties…")
			return res
		}
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
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
		.then{ _ in Future<GoogleUser>.future(from: op, eventLoop: container.eventLoop) }
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
			return try self.existingUser(fromUserId: email, propertiesToFetch: propertiesToFetch, on: container)
		}
		return future
	}
	
}
