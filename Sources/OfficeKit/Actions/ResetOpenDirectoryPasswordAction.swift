/*
 * ResetOpenDirectoryPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 21/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import SemiSingleton
import Vapor



public class ResetOpenDirectoryPasswordAction : Action<User, String, Void>, SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Container
	
	public let container: Container
	
	/* Contains the OpenDirectory user id as soon as the user is found (after the
	 * operation is started). */
	public var openDirectoryUserId: LDAPDistinguishedName?
	
	public required init(key u: User, additionalInfo: Container, store: SemiSingletonStore) {
		container = additionalInfo
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Error>) -> Void) throws {
		openDirectoryUserId = nil /* We re-search for the user, so we clear the current user id we have */
		
		let asyncConfig = try container.make(AsyncConfig.self)
		let singletonStore = try container.make(SemiSingletonStore.self)
		
		let openDirectorySettings = try container.make(OfficeKitConfig.self).openDirectoryConfigOrThrow()
		let connector = try singletonStore.semiSingleton(forKey: openDirectorySettings.connectorSettings) as OpenDirectoryConnector
		let authenticator = try singletonStore.semiSingleton(forKey: openDirectorySettings.authenticatorSettings) as OpenDirectoryRecordAuthenticator
		
		let f = try connector
		.connect(scope: (), asyncConfig: asyncConfig)
		.and(subject.existingOpenDirectoryUser(container: container))
		.thenThrowing{ (_, openDirectoryRecord) -> ODRecord in
			let u = try nil2throw(openDirectoryRecord, "No Google user found for given user")
			let attributes = try u.recordDetails(forAttributes: nil)
			let id = try nil2throw((attributes[kODAttributeTypeMetaRecordName] as? [String])?.first)
			self.openDirectoryUserId = try LDAPDistinguishedName(string: id) /* We set the user id as soon as we have it. */
			return u
		}
		.then{ openDirectoryRecord -> Future<Void> in
			let modifyUserOperation = ModifyOpenDirectoryPasswordOperation(record: openDirectoryRecord, newPassword: newPassword, authenticator: authenticator)
			return asyncConfig.eventLoop.future(from: modifyUserOperation, queue: asyncConfig.operationQueue)
		}
		f.whenSuccess{ _ in
			/* Success! Let’s call the handler. */
			handler(.success(()))
		}
		f.whenFailure{ error in
			/* Error. Let’s call the handler. */
			handler(.failure(error))
		}
	}
	
}

#endif
