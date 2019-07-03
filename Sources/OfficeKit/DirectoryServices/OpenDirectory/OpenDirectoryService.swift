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
	public typealias UserIdType = ODRecord
	public typealias AuthenticationChallenge = String
	
	public let config: OpenDirectoryServiceConfig
	
	public init(config c: OpenDirectoryServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		config = c
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		openDirectoryConnector = try sms.semiSingleton(forKey: c.connectorSettings)
		openDirectoryRecordAuthenticator = try sms.semiSingleton(forKey: c.authenticatorSettings)
	}
	
	public func logicalUser(from email: Email) throws -> ODRecord? {
		throw NotImplementedError()
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> ODRecord? {
		throw NotImplementedError()
	}
	
	public func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<ODRecord?> {
		#warning("TODO: Implement propertiesToFetch")
		let request = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(email.username.utf8)], returnAttributes: nil, maximumResults: 2)
		return asyncConfig.eventLoop.future()
			.flatMap{ _ in try self.existingRecord(fromSearchRequest: request)}
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<ODRecord?> {
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
	
	public func listAllUsers() -> Future<[ODRecord]> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: ODRecord) -> Future<ODRecord> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: ODRecord, propertiesToUpdate: Set<DirectoryUserProperty>) -> Future<ODRecord> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: ODRecord) -> Future<Void> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: ODRecord) throws -> ResetPasswordAction {
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: (asyncConfig, openDirectoryConnector, openDirectoryRecordAuthenticator)) as ResetOpenDirectoryPasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let asyncConfig: AsyncConfig
	private let semiSingletonStore: SemiSingletonStore
	
	private let openDirectoryConnector: OpenDirectoryConnector
	private let openDirectoryRecordAuthenticator: OpenDirectoryRecordAuthenticator
	
	private func existingRecord(fromSearchRequest request: OpenDirectorySearchRequest) throws -> Future<ODRecord?> {
		let future = openDirectoryConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> Future<[ODRecord]> in
			let op = SearchOpenDirectoryOperation(openDirectoryConnector: self.openDirectoryConnector, request: request)
			return self.asyncConfig.eventLoop.future(from: op, queue: self.asyncConfig.operationQueue)
		}
		.thenThrowing{ objects -> ODRecord? in
			guard objects.count <= 1 else {
				throw UserIdConversionError.tooManyUsersFound
			}
			return objects.first
		}
		return future
	}
	
}

#endif
