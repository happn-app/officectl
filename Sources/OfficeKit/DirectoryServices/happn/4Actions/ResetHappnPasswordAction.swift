/*
 * ResetHappnPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/18.
 */

import Foundation

import NIO
import SemiSingleton
import ServiceKit



public final class ResetHappnPasswordAction : Action<HappnUser, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public static func additionalInfo(from services: Services) throws -> HappnConnector {
		return try (services.semiSingleton(forKey: services.make()))
	}
	
	public typealias SemiSingletonKey = HappnUser
	public typealias SemiSingletonAdditionalInitInfo = HappnConnector
	
	public required init(key id: HappnUser, additionalInfo: HappnConnector, store: SemiSingletonStore) {
		deps = Dependencies(connector: additionalInfo)
		
		super.init(subject: id)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Swift.Error>) -> Void) throws {
		Task{await handler(Result{
			try await deps.connector.connect(ModifyHappnUserOperation.scopes)
			
			var happnUser = self.subject.cloneForPatching()
			happnUser.password = newPassword
			
			let modifyUserOperation = ModifyHappnUserOperation(user: happnUser, connector: self.deps.connector)
			/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
			try await modifyUserOperation.startAndGetResult()
		})}
	}
	
	private struct Dependencies {
		
		var connector: HappnConnector
		
	}
	
	private let deps: Dependencies
	
}
