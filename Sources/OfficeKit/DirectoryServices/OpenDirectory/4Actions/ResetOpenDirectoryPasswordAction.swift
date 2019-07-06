/*
 * ResetOpenDirectoryPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 21/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import NIO
import SemiSingleton
import Service



public class ResetOpenDirectoryPasswordAction : Action<ODRecord, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public static func additionalInfo(from container: Container) throws -> (OpenDirectoryConnector, OpenDirectoryRecordAuthenticator) {
		return try (container.make(SemiSingletonStore.self).semiSingleton(forKey: container.make()), container.make(SemiSingletonStore.self).semiSingleton(forKey: container.make()))
	}
	
	public typealias SemiSingletonKey = ODRecord
	public typealias SemiSingletonAdditionalInitInfo = (OpenDirectoryConnector, OpenDirectoryRecordAuthenticator)
	
	public required init(key u: ODRecord, additionalInfo: (OpenDirectoryConnector, OpenDirectoryRecordAuthenticator), store: SemiSingletonStore) {
		deps = Dependencies(connector: additionalInfo.0, authenticator: additionalInfo.1)
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Error>) -> Void) throws {
		/* We use futures for style. */
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		
		let f = deps.connector.connect(scope: (), eventLoop: eventLoop)
		.then{ _ -> Future<Void> in
			let modifyUserOperation = ModifyOpenDirectoryPasswordOperation(record: self.subject, newPassword: newPassword, authenticator: self.deps.authenticator)
			return Future<Void>.future(from: modifyUserOperation, eventLoop: eventLoop)
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
		
		var connector: OpenDirectoryConnector
		var authenticator: OpenDirectoryRecordAuthenticator
		
	}
	
	private let deps: Dependencies
	
}

#endif
