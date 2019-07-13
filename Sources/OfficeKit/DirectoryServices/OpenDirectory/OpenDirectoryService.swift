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
import GenericJSON
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
	
	public func string(fromUserId userId: LDAPDistinguishedName) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> LDAPDistinguishedName {
		return try LDAPDistinguishedName(string: string)
	}
	
	public func shortDescription(from user: ODRecordOKWrapper) -> String {
		return user.userId.stringValue
	}
	
	public func exportableJSON(from user: ODRecordOKWrapper) throws -> JSON {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromPersistentId pId: UUID, hints: [DirectoryUserProperty : Any]) throws -> ODRecordOKWrapper {
		throw NotSupportedError(message: "It is not possible to create an OpenDirectory user from its persistent id without fetching it.")
	}
	
	public func logicalUser(fromUserId uId: LDAPDistinguishedName, hints: [DirectoryUserProperty : Any]) throws -> ODRecordOKWrapper {
		let fullNameComponents = [hints[.firstName] as? String, hints[.lastName] as? String].compactMap{ $0 }
		let fullName = (!fullNameComponents.isEmpty ? fullNameComponents.joined(separator: " ") : nil)
		let inetOrgPerson = LDAPInetOrgPerson(
			dn: uId,
			sn: (hints[.lastName] as? String).flatMap{ [$0] } ?? [],
			cn: fullName.flatMap{ [$0] } ?? []
		)
		let emails = hints[.emails] as? [Email]
		inetOrgPerson.mail = emails
		return ODRecordOKWrapper(
			id: uId,
			emails: emails ?? [], firstName: hints[.firstName] as? String, lastName: hints[.lastName] as? String
		)
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any]) throws -> ODRecordOKWrapper {
		guard let peopleBaseDNPerDomain = config.peopleBaseDNPerDomain else {
			throw InvalidArgumentError(message: "Cannot get logical user from \(email) when I don’t have people base DNs.")
		}
		guard let baseDN = peopleBaseDNPerDomain[email.domain] else {
			throw InvalidArgumentError(message: "Cannot get logical user from \(email) because its domain people base DN is unknown.")
		}
		
		var hints = hints
		if hints[.emails] as? [Email] == nil {hints[.emails] = [email]}
		return try logicalUser(fromUserId: LDAPDistinguishedName(uid: email.username, baseDN: baseDN), hints: hints)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any]) throws -> ODRecordOKWrapper {
		if service.config.serviceId == config.serviceId, let user: UserType = user.unboxed() {
			/* The given user is already from our service; let’s return it. */
			return user
		}
		
		if let (_, user) = try dsuPairFrom(service: service, user: user) as DSUPair<GoogleService>? {
			var ret = try logicalUser(fromEmail: user.primaryEmail, hints: hints)
			if let gn = user.name.value?.givenName,  ret.firstName.value == nil {ret.firstName = .set(gn)}
			if let fn = user.name.value?.familyName, ret.lastName.value  == nil {ret.lastName  = .set(fn)}
			return ret
		}
		throw NotImplementedError()
	}
	
	public func existingUser(fromPersistentId pId: UUID, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: LDAPDistinguishedName, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		#warning("TODO: Implement propertiesToFetch")
		let request = OpenDirectorySearchRequest(uid: email.username, maxResults: 2)
		return try existingRecord(fromSearchRequest: request, on: container)
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<ODRecordOKWrapper?> {
		if let (_, ldapUser) = try dsuPairFrom(service: service, user: user) as DSUPair<LDAPService>? {
			guard let uid = ldapUser.userId.uid else {throw UserIdConversionError.uidMissingInDN}
			let request = OpenDirectorySearchRequest(uid: uid, maxResults: 2)
			return try existingRecord(fromSearchRequest: request, on: container)
		}
		
		throw UserIdConversionError.unsupportedServiceUserIdConversion
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
