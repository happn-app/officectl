/*
 * GoogleService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Async
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
	
	public init(config c: GoogleServiceConfig) throws {
		config = c
	}
	
	public func string(from userId: String) -> String {
		return userId
	}
	
	public func userId(from string: String) throws -> String {
		return string
	}
	
	public func logicalUser(from email: Email) throws -> GoogleUser? {
		throw NotImplementedError()
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> GoogleUser? {
		throw NotImplementedError()
	}
	
	public func existingUser(from id: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GoogleUser?> {
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
		switch (service, user) {
		case let (ldapService as LDAPService, ldapUser as LDAPService.UserType):
			return try self.existingGoogleUser(fromLDAP: ldapUser, ldapService: ldapService, propertiesToFetch: propertiesToFetch, on: container)
			
		default:
			throw UserIdConversionError.unsupportedServiceUserIdConversion
		}
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
		throw NotImplementedError()
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
		let asyncConfig: AsyncConfig = try container.make()
		let semiSingletonStore: SemiSingletonStore = try container.make()
		let googleConnector: GoogleJWTConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: (asyncConfig, googleConnector)) as ResetGooglePasswordAction
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
			return try self.existingUser(from: email, propertiesToFetch: propertiesToFetch, on: container)
		}
		return future
	}
	
}
