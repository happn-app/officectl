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
	
	public typealias UserIdType = ODRecord
	public typealias AuthenticationChallenge = String
	
	public let supportsPasswordChange = true
	public let serviceConfig: OpenDirectoryServiceConfig
	
	public init(config: OpenDirectoryServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceConfig = config
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		openDirectoryConnector = try sms.semiSingleton(forKey: config.connectorSettings)
		openDirectoryRecordAuthenticator = try sms.semiSingleton(forKey: config.authenticatorSettings)
	}
	
	public func existingUserId(from email: Email) -> Future<ODRecord?> {
		let request = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(email.username.utf8)], returnAttributes: nil, maximumResults: 2)
		return asyncConfig.eventLoop.future()
			.flatMap{ _ in try self.existingRecord(fromSearchRequest: request)}
	}
	
	public func existingUserId<T : DirectoryService>(from userId: T.UserIdType, in service: T) -> Future<ODRecord?> {
		return asyncConfig.eventLoop.future()
		.flatMap{ _ in
			switch (service, userId) {
			case let (_ as LDAPService, dn as LDAPService.UserIdType):
				guard let uid = dn.uid else {throw UserIdConversionError.uidMissingInDN}
				let request = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(uid.utf8)], returnAttributes: nil, maximumResults: 2)
				return try self.existingRecord(fromSearchRequest: request)
				
			default:
				throw UserIdConversionError.unsupportedServiceUserIdConversion
			}
		}
	}
	
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
