/*
 * OpenDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import Async
import SemiSingleton



public final class OpenDirectoryService : DirectoryService {
	
	public static let providerId = "internal_opendirectory"
	
	public enum UserIdConversionError : Error {
		
		case uidMissingInDN
		case tooManyUsersFound
		case unsupportedServiceUserIdConversion
		
	}
	
	public typealias ConfigType = OpenDirectoryServiceConfig
	public typealias UserIdType = ODRecordOKWrapper
	public typealias AuthenticationChallenge = String
	
	public let config: OpenDirectoryServiceConfig
	
	public init(config c: OpenDirectoryServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		config = c
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		openDirectoryConnector = try sms.semiSingleton(forKey: c.connectorSettings)
		openDirectoryRecordAuthenticator = try sms.semiSingleton(forKey: c.authenticatorSettings)
	}
	
	public func string(from userId: LDAPDistinguishedName) -> String {
		return userId.stringValue
	}
	
	public func userId(from string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func logicalUser(from email: Email) throws -> ODRecordOKWrapper? {
		throw NotImplementedError()
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> ODRecordOKWrapper? {
		if let user = user as? GoogleUser {
			guard let peopleBaseDNPerDomain = config.peopleBaseDNPerDomain else {
				throw InvalidArgumentError(message: "Cannot get logical user from \(user) when I don’t have people base DNs.")
			}
			guard let baseDN = peopleBaseDNPerDomain[user.primaryEmail.domain] else {
				/* If the domain of the Google user is not supported in the LDAP
				 * config, we return a nil logical user: the user cannot exist in
				 * the LDAP in this state, but it’s not an actual error.
				 * TODO: Make sure we actually do want that and not raise a “well-
				 *       known” error instead, that clients could catch… */
				return nil
			}
			return ODRecordOKWrapper(
				id: LDAPDistinguishedName(uid: user.primaryEmail.username, baseDN: baseDN),
				emails: [user.primaryEmail], firstName: user.name.givenName, lastName: user.name.familyName
			)
		}
		throw NotImplementedError()
	}
	
	public func existingUser(from id: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>) -> EventLoopFuture<ODRecordOKWrapper?> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<ODRecordOKWrapper?> {
		#warning("TODO: Implement propertiesToFetch")
		let request = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(email.username.utf8)], returnAttributes: nil, maximumResults: 2)
		return asyncConfig.eventLoop.future()
			.flatMap{ _ in try self.existingRecord(fromSearchRequest: request)}
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<ODRecordOKWrapper?> {
		return asyncConfig.eventLoop.future()
		.flatMap{ _ in
			switch (service, user) {
			case let (_ as LDAPService, ldapUser as LDAPService.UserType):
				guard let uid = ldapUser.id.uid else {throw UserIdConversionError.uidMissingInDN}
				let request = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(uid.utf8)], returnAttributes: nil, maximumResults: 2)
				return try self.existingRecord(fromSearchRequest: request)
				
			default:
				throw UserIdConversionError.unsupportedServiceUserIdConversion
			}
		}
	}
	
	public func listAllUsers() -> Future<[ODRecordOKWrapper]> {
		let searchQuery = OpenDirectorySearchRequest(recordTypes:  [kODRecordTypeUsers], attribute: kODAttributeTypeMetaRecordName, matchType: ODMatchType(kODMatchAny), queryValues: nil, returnAttributes: nil, maximumResults: nil)
		let op = SearchOpenDirectoryOperation(openDirectoryConnector: openDirectoryConnector, request: searchQuery)
		return openDirectoryConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ self.asyncConfig.eventLoop.future(from: op, queue: self.asyncConfig.operationQueue).map{ $0.compactMap{ try? ODRecordOKWrapper(record: $0) } } }
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: ODRecordOKWrapper) -> Future<ODRecordOKWrapper> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: ODRecordOKWrapper, propertiesToUpdate: Set<DirectoryUserProperty>) -> Future<ODRecordOKWrapper> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: ODRecordOKWrapper) -> Future<Void> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: ODRecordOKWrapper) throws -> ResetPasswordAction {
		guard let record = user.record else {throw InvalidArgumentError(message: "Got a user without a record to reset password.")}
		return semiSingletonStore.semiSingleton(forKey: record, additionalInitInfo: (asyncConfig, openDirectoryConnector, openDirectoryRecordAuthenticator)) as ResetOpenDirectoryPasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let asyncConfig: AsyncConfig
	private let semiSingletonStore: SemiSingletonStore
	
	private let openDirectoryConnector: OpenDirectoryConnector
	private let openDirectoryRecordAuthenticator: OpenDirectoryRecordAuthenticator
	
	private func existingRecord(fromSearchRequest request: OpenDirectorySearchRequest) throws -> Future<ODRecordOKWrapper?> {
		let future = openDirectoryConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> Future<[ODRecord]> in
			let op = SearchOpenDirectoryOperation(openDirectoryConnector: self.openDirectoryConnector, request: request)
			return self.asyncConfig.eventLoop.future(from: op, queue: self.asyncConfig.operationQueue)
		}
		.thenThrowing{ objects -> ODRecordOKWrapper? in
			guard objects.count <= 1 else {
				throw UserIdConversionError.tooManyUsersFound
			}
			return try objects.first.flatMap{ try ODRecordOKWrapper(record: $0) }
		}
		return future
	}
	
}

#endif
