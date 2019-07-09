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
import Service



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
	
	public init(config c: OpenDirectoryServiceConfig) {
		config = c
	}
	
	public func string(from userId: LDAPDistinguishedName) -> String {
		return userId.stringValue
	}
	
	public func userId(from string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func logicalUser(fromEmail email: Email) throws -> ODRecordOKWrapper? {
		guard let peopleBaseDNPerDomain = config.peopleBaseDNPerDomain else {
			throw InvalidArgumentError(message: "Cannot get logical user from \(email) when I don’t have people base DNs.")
		}
		guard let baseDN = peopleBaseDNPerDomain[email.domain] else {
			/* If the domain of the email is not supported in the LDAP config, we
			 * return a nil logical user: the user cannot exist in the LDAP in this
			 * state, but it’s not an actual error.
			 * TODO: Make sure we actually do want that and not raise a “well-
			 *       known” error instead, that clients could catch… */
			return nil
		}
		return ODRecordOKWrapper(
			id: LDAPDistinguishedName(uid: email.username, baseDN: baseDN),
			emails: [email]
		)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType) throws -> ODRecordOKWrapper? {
		if let user = user as? GoogleUser {
			var ret = try logicalUser(fromEmail: user.primaryEmail)
			if let gn = user.name.value?.givenName  {ret?.firstName = .set(gn)}
			if let fn = user.name.value?.familyName {ret?.lastName  = .set(fn)}
			return ret
		}
		throw NotImplementedError()
	}
	
	public func existingUser(fromPersistentId pId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<ODRecordOKWrapper?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<ODRecordOKWrapper?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		#warning("TODO: Implement propertiesToFetch")
		let request = OpenDirectorySearchRequest(uid: email.username, maxResults: 2)
		return try existingRecord(fromSearchRequest: request, on: container)
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		switch (service, user) {
		case let (_ as LDAPService, ldapUser as LDAPService.UserType):
			guard let uid = ldapUser.userId.uid else {throw UserIdConversionError.uidMissingInDN}
			let request = OpenDirectorySearchRequest(uid: uid, maxResults: 2)
			return try existingRecord(fromSearchRequest: request, on: container)
			
		default:
			throw UserIdConversionError.unsupportedServiceUserIdConversion
		}
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[ODRecordOKWrapper]> {
		let openDirectoryConnector: OpenDirectoryConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		
		let searchQuery = OpenDirectorySearchRequest(recordTypes:  [kODRecordTypeUsers], attribute: kODAttributeTypeMetaRecordName, matchType: ODMatchType(kODMatchAny), queryValues: nil, returnAttributes: nil, maximumResults: nil)
		let op = SearchOpenDirectoryOperation(request: searchQuery, openDirectoryConnector: openDirectoryConnector)
		return openDirectoryConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ Future<[ODRecord]>.future(from: op, eventLoop: container.eventLoop).map{ $0.compactMap{ try? ODRecordOKWrapper(record: $0) } } }
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: ODRecordOKWrapper, on container: Container) throws -> Future<ODRecordOKWrapper> {
		throw NotImplementedError()
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: ODRecordOKWrapper, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper> {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: ODRecordOKWrapper, on container: Container) throws -> Future<Void> {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: ODRecordOKWrapper, on container: Container) throws -> ResetPasswordAction {
		let semiSingletonStore: SemiSingletonStore = try container.make()
		let openDirectoryConnector: OpenDirectoryConnector = try semiSingletonStore.semiSingleton(forKey: config.connectorSettings)
		let openDirectoryRecordAuthenticator: OpenDirectoryRecordAuthenticator = try semiSingletonStore.semiSingleton(forKey: config.authenticatorSettings)
		return semiSingletonStore.semiSingleton(forKey: user.userId, additionalInitInfo: (openDirectoryConnector, openDirectoryRecordAuthenticator)) as ResetOpenDirectoryPasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func existingRecord(fromSearchRequest request: OpenDirectorySearchRequest, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		let openDirectoryConnector: OpenDirectoryConnector = try container.makeSemiSingleton(forKey: config.connectorSettings)
		let future = openDirectoryConnector.connect(scope: (), eventLoop: container.eventLoop)
		.then{ _ -> Future<[ODRecord]> in
			let op = SearchOpenDirectoryOperation(request: request, openDirectoryConnector: openDirectoryConnector)
			return Future<[ODRecord]>.future(from: op, eventLoop: container.eventLoop)
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
