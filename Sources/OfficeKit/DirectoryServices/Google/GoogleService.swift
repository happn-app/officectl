/*
 * GoogleService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Async
import SemiSingleton



public final class GoogleService : DirectoryService {
	
	public static let providerId = "internal_google"
	
	public enum UserIdConversionError : Error {
		
		case noEmailInLDAP
		case multipleEmailInLDAP
		
		case tooManyUsersFound
		case unsupportedServiceUserIdConversion
		
		case internalError
		
	}
	
	public typealias UserType = GoogleUser
	
	public let serviceConfig: GoogleServiceConfig
	
	public init(config: GoogleServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceConfig = config
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		googleConnector = try sms.semiSingleton(forKey: config.connectorSettings)
	}
	
	public func logicalUser(from email: Email) throws -> GoogleUser {
		throw NotImplementedError()
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> GoogleUser {
		throw NotImplementedError()
	}
	
	public func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<GoogleUser?> {
		#warning("TODO: Implement propertiesToFetch")
		/* Note: We do **NOT** map the email to the main domain. Maybe we should? */
		let future = googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
		.then{ _ -> Future<[GoogleUser]> in
			let op = SearchGoogleUsersOperation(searchedDomain: email.domain, query: #"email="\#(email.stringValue)""#, googleConnector: self.googleConnector)
			return self.asyncConfig.eventLoop.future(from: op, queue: self.asyncConfig.operationQueue)
		}
		.thenThrowing{ objects -> GoogleUser? in
			guard objects.count <= 1 else {
				throw UserIdConversionError.tooManyUsersFound
			}
			return objects.first
		}
		return future
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<GoogleUser?> {
		return asyncConfig.eventLoop.future()
		.flatMap{ _ in
			switch (service, user) {
			case let (ldapService as LDAPService, ldapUser as LDAPService.UserType):
				return try self.existingGoogleUser(fromLDAP: ldapUser, ldapService: ldapService, propertiesToFetch: propertiesToFetch)
				
			default:
				throw UserIdConversionError.unsupportedServiceUserIdConversion
			}
		}
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: GoogleUser) -> Future<GoogleUser> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: GoogleUser, propertiesToUpdate: Set<DirectoryUserProperty>) -> Future<GoogleUser> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: GoogleUser) -> Future<Void> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: GoogleUser) throws -> ResetPasswordAction {
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: (asyncConfig, googleConnector)) as ResetGooglePasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let asyncConfig: AsyncConfig
	private let semiSingletonStore: SemiSingletonStore
	
	private let googleConnector: GoogleJWTConnector
	
	private func existingGoogleUser(fromLDAP ldapUser: LDAPService.UserType, ldapService: LDAPService, propertiesToFetch: Set<DirectoryUserProperty>) throws -> Future<GoogleUser?> {
		let future = ldapService.fetchUniqueEmails(from: ldapUser).map{ emails in
			guard emails.count <= 1 else {throw UserIdConversionError.multipleEmailInLDAP}
			guard let email = emails.first else {throw UserIdConversionError.noEmailInLDAP}
			return email
		}
		.then{ email -> Future<GoogleUser?> in
			return self.existingUser(from: email, propertiesToFetch: propertiesToFetch)
		}
		return future
	}
	
}
