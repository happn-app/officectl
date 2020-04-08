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
import ServiceKit



public final class ResetOpenDirectoryPasswordAction : Action<LDAPDistinguishedName, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public static func additionalInfo(from services: Services) throws -> OpenDirectoryConnector {
		return try services.semiSingleton(forKey: services.make())
	}
	
	public typealias SemiSingletonKey = LDAPDistinguishedName
	public typealias SemiSingletonAdditionalInitInfo = OpenDirectoryConnector
	
	public required init(key u: LDAPDistinguishedName, additionalInfo: OpenDirectoryConnector, store: SemiSingletonStore) {
		deps = Dependencies(connector: additionalInfo)
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Error>) -> Void) throws {
		guard let uid = subject.uid else {
			throw InvalidArgumentError(message: "Did not get a UID in the given DN.")
		}
		
		/* We use futures for style. */
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		
		let f = deps.connector.connect(scope: (), eventLoop: eventLoop)
		.flatMap{ _ -> EventLoopFuture<[ODRecord]> in
			/* Ideally I’d like to search for the DN directly, but for the life of
			 * me, I cannot find a way to do this! OpenDirectory is awesome. */
			let op = SearchOpenDirectoryOperation(uid: uid, maxResults: 2, returnAttributes: nil, openDirectoryConnector: self.deps.connector)
			return EventLoopFuture<[ODRecord]>.future(from: op, on: eventLoop)
		}
		.flatMapThrowing{ users -> ODRecord in
			guard let user = users.onlyElement else {
				throw InvalidArgumentError(message: "Given DN has no, or more than one matching record")
			}
			return user
		}
		.flatMap{ user -> EventLoopFuture<Void> in
			let modifyUserOperation = ModifyOpenDirectoryPasswordOperation(record: user, newPassword: newPassword)
			return EventLoopFuture<Void>.future(from: modifyUserOperation, on: eventLoop)
		}
		
		f.whenSuccess{ _   in handler(.success(())) }
		f.whenFailure{ err in handler(.failure(err)) }
	}
	
	private struct Dependencies {
		
		var connector: OpenDirectoryConnector
		
	}
	
	private let deps: Dependencies
	
}

#endif
