/*
 * ResetLDAPPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/11/2018.
 */

import Foundation

import SemiSingleton
import ServiceKit



public final class ResetLDAPPasswordAction : Action<LDAPDistinguishedName, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public static func additionalInfo(using services: Services) throws -> LDAPConnector {
		return try services.semiSingleton(forKey: services.make())
	}
	
	public typealias SemiSingletonKey = LDAPDistinguishedName
	public typealias SemiSingletonAdditionalInitInfo = LDAPConnector
	
	public required init(key u: LDAPDistinguishedName, additionalInfo: LDAPConnector, store: SemiSingletonStore) {
		deps = Dependencies(connector: additionalInfo)
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Error>) -> Void) throws {
		/* Note: To be symmetrical with the reset google user action, we could use the existingLDAPUser method. */
		deps.connector.connect(scope: (), handler: { result in
			if let e = result.failureValue {return handler(.failure(e))}
			
			let operation = ModifyLDAPPasswordsOperation(resets: [(self.subject, newPassword)], connector: self.deps.connector)
			operation.completionBlock = {
				if let e = operation.errors[0] {handler(.failure(e))}
				else                           {handler(.success(()))}
			}
			defaultOperationQueueForFutureSupport.addOperations([operation], waitUntilFinished: false)
		})
	}
	
	private struct Dependencies {
		
		var connector: LDAPConnector
		
	}
	
	private let deps: Dependencies
	
}
