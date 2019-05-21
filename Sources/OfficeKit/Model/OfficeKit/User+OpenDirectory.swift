/*
 * User+OpenDirectory.swift
 * OfficeKit
 *
 * Created by François Lamboley on 21/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import SemiSingleton
import Vapor



extension User {
	
	public func bestOpenDirectorySearchQuery(officeKitConfig: OfficeKitConfig) throws -> OpenDirectorySearchRequest {
		if let uid = distinguishedName?.uid {
			return OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(uid.utf8)], returnAttributes: nil, maximumResults: 2)
		}
		if let email = email {
			return OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(email.username.utf8)], returnAttributes: nil, maximumResults: 2)
		}
		throw InvalidArgumentError(message: "Cannot find an OpenDirectory query to fetch user with id “\(id)”")
	}
	
	public func existingOpenDirectoryUser(container: Container) throws -> Future<ODRecord?> {
		let asyncConfig = try container.make(AsyncConfig.self)
		let officeKitConfig = try container.make(OfficeKitConfig.self)
		let semiSingletonStore = try container.make(SemiSingletonStore.self)
		let openDirectoryConnectorConfig = try officeKitConfig.openDirectoryConfigOrThrow().connectorSettings
		let openDirectoryConnector: OpenDirectoryConnector = try semiSingletonStore.semiSingleton(forKey: openDirectoryConnectorConfig)
		
		let request = try bestOpenDirectorySearchQuery(officeKitConfig: officeKitConfig)
		
		let future = openDirectoryConnector.connect(scope: (), asyncConfig: asyncConfig)
		.then{ _ -> EventLoopFuture<[ODRecord]> in
			let op = SearchOpenDirectoryOperation(openDirectoryConnector: openDirectoryConnector, request: request)
			return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue)
		}
		.thenThrowing{ objects -> ODRecord? in
			guard objects.count <= 1 else {
				throw Error.tooManyUsersFound
			}
			return objects.first
		}
		return future
	}
	
}

#endif
