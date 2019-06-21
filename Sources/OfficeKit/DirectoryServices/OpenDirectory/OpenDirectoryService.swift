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



public class OpenDirectoryService : DirectoryService {
	
	public enum UserIdConversionError : Error {
		
		case uidMissingInDN
		case tooManyUsersFound
		case unsupportedServiceUserIdConversion
		
	}
	
	public static let id = "internal_opendirectory"
	
	public typealias UserIdType = ODRecord
	public typealias AuthenticationChallenge = String
	
	public let supportsPasswordChange = true
	
	public let serviceId: String
	public let serviceName: String
	public let asyncConfig: AsyncConfig
	public let openDirectoryConfig: OpenDirectoryServiceConfig
	public let semiSingletonStore: SemiSingletonStore
	
	public let openDirectoryConnector: OpenDirectoryConnector
	public let openDirectoryRecordAuthenticator: OpenDirectoryRecordAuthenticator
	
	public init(id: String, name: String, ldapConfig config: OpenDirectoryServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceId = id
		asyncConfig = ac
		serviceName = name
		openDirectoryConfig = config
		semiSingletonStore = sms
		
		openDirectoryConnector = try sms.semiSingleton(forKey: config.connectorSettings)
		openDirectoryRecordAuthenticator = try sms.semiSingleton(forKey: config.authenticatorSettings)
	}
	
	public func existingUserId(from email: Email) -> Future<ODRecord?> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public func existingUserId<T>(from userId: T.UserIdType, in service: T) -> Future<ODRecord?> where T : DirectoryService {
		asyncConfig.eventLoop.future()
		.flatMap{ _ in
			switch (service, userId) {
			case let (_ as LDAPService, dn as LDAPService.UserIdType):
				return try self.existingRecord(fromLDAP: dn)
				
			default:
				throw UserIdConversionError.unsupportedServiceUserIdConversion
			}
		}
	}
	
	public func changePasswordAction(for user: ODRecord) throws -> Action<ODRecord, String, Void> {
		return semiSingletonStore.semiSingleton(forKey: user, additionalInitInfo: (asyncConfig, openDirectoryConnector, openDirectoryRecordAuthenticator)) as ResetOpenDirectoryPasswordAction
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func existingRecord(fromLDAP dn: LDAPDistinguishedName) throws -> Future<ODRecord?> {
		guard let uid = dn.uid else {throw UserIdConversionError.uidMissingInDN}
		
		let future = openDirectoryConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> Future<[ODRecord]> in
			let request = OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(uid.utf8)], returnAttributes: nil, maximumResults: 2)
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
