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



public class ResetOpenDirectoryPasswordAction : Action<ODRecord, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public static func additionalInfo(from container: Container) throws -> (AsyncConfig, OpenDirectoryConnector, OpenDirectoryRecordAuthenticator) {
		return try (container.make(), container.make(SemiSingletonStore.self).semiSingleton(forKey: container.make()), container.make(SemiSingletonStore.self).semiSingleton(forKey: container.make()))
	}
	
	public typealias SemiSingletonKey = ODRecord
	public typealias SemiSingletonAdditionalInitInfo = (AsyncConfig, OpenDirectoryConnector, OpenDirectoryRecordAuthenticator)
	
	public required init(key u: ODRecord, additionalInfo: (AsyncConfig, OpenDirectoryConnector, OpenDirectoryRecordAuthenticator), store: SemiSingletonStore) {
		deps = Dependencies(asyncConfig: additionalInfo.0, connector: additionalInfo.1, authenticator: additionalInfo.2)
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Error>) -> Void) throws {
		let f = deps.connector
		.connect(scope: (), asyncConfig: deps.asyncConfig)
		.then{ _ -> Future<Void> in
			let modifyUserOperation = ModifyOpenDirectoryPasswordOperation(record: self.subject, newPassword: newPassword, authenticator: self.deps.authenticator)
			return self.deps.asyncConfig.eventLoop.future(from: modifyUserOperation, queue: self.deps.asyncConfig.operationQueue)
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
	
	private struct Dependencies {
		
		var asyncConfig: AsyncConfig
		var connector: OpenDirectoryConnector
		var authenticator: OpenDirectoryRecordAuthenticator
		
	}
	
	private let deps: Dependencies
	
}

#endif
