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
		Task{await handler(Result{
			/* Note: To be symmetrical with the reset google user action, we could use the existingLDAPUser method. */
			try await deps.connector.connect()
			
			let operation = ModifyLDAPPasswordsOperation(resets: [(self.subject, newPassword)], connector: self.deps.connector)
			await operation.startAndWait()
			if let e = operation.errors[0] {
				throw e
			}
		})}
	}
	
	private struct Dependencies {
		
		var connector: LDAPConnector
		
	}
	
	private let deps: Dependencies
	
}
