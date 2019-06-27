/*
 * GoogleService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Async
import SemiSingleton



public class GoogleService : DirectoryService {
	
	public enum UserIdConversionError : Error {
		
		case noEmailInLDAP
		case multipleEmailInLDAP
		
		case tooManyUsersFound
		case unsupportedServiceUserIdConversion
		
		case internalError
		
	}
	
	public let supportsPasswordChange = true
	
	public let serviceConfig: GoogleServiceConfig
	
	public init(config: GoogleServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceConfig = config
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		googleConnector = try sms.semiSingleton(forKey: config.connectorSettings)
	}
	
	public func existingUserId(from email: Email) -> some EventLoopFuture<Hashable?> {
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
	
	public func existingUserId<T>(from userId: T.UserIdType, in service: T) -> Future<GoogleUser?> where T : DirectoryService {
		asyncConfig.eventLoop.future()
		.flatMap{ _ in
			switch (service, userId) {
			case let (ldapService as LDAPService, dn as LDAPService.UserIdType):
				return try self.existingGoogleUser(fromLDAP: dn, ldapService: ldapService)
				
			default:
				throw UserIdConversionError.unsupportedServiceUserIdConversion
			}
		}
	}
	
	public func changePasswordAction(for user: GoogleUser) throws -> Action<GoogleUser, String, Void> {
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: (asyncConfig, googleConnector)) as ResetGooglePasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let asyncConfig: AsyncConfig
	private let semiSingletonStore: SemiSingletonStore
	
	private let googleConnector: GoogleJWTConnector
	
	private func existingGoogleUser(fromLDAP dn: LDAPDistinguishedName, ldapService: LDAPService) throws -> Future<GoogleUser?> {
		let future = ldapService.fetchUniqueEmails(from: dn).map{ emails in
			guard emails.count <= 1 else {throw UserIdConversionError.multipleEmailInLDAP}
			guard let email = emails.first else {throw UserIdConversionError.noEmailInLDAP}
			return email
		}
		.then{ email -> Future<GoogleUser?> in
			return self.existingUserId(from: email)
		}
		return future
	}
	
}
