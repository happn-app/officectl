/*
 * ResetHappnPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/09/2018.
 */

import Foundation

import SemiSingleton
import Vapor



public class ResetHappnPasswordAction : Action<HappnUser, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public static func additionalInfo(from container: Container) throws -> HappnConnector {
		return try (container.make(SemiSingletonStore.self).semiSingleton(forKey: container.make()))
	}
	
	public typealias SemiSingletonKey = HappnUser
	public typealias SemiSingletonAdditionalInitInfo = HappnConnector
	
	public required init(key id: HappnUser, additionalInfo: HappnConnector, store: SemiSingletonStore) {
		deps = Dependencies(connector: additionalInfo)
		
		super.init(subject: id)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Swift.Error>) -> Void) throws {
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		
		let f = deps.connector.connect(scope: ModifyHappnUserOperation.scopes, eventLoop: eventLoop)
		.map{ _ -> EventLoopFuture<Void> in
			var happnUser = self.subject.cloneForPatching()
			
			happnUser.password = .set(newPassword)
			
			let modifyUserOperation = ModifyHappnUserOperation(user: happnUser, connector: self.deps.connector)
			return EventLoopFuture<Void>.future(from: modifyUserOperation, on: eventLoop)
		}
		
		f.whenSuccess{ _   in handler(.success(())) }
		f.whenFailure{ err in handler(.failure(err)) }
	}
	
	private struct Dependencies {
		
		var connector: HappnConnector
		
	}
	
	private let deps: Dependencies
	
}
