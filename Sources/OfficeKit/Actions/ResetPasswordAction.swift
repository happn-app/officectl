/*
 * ResetPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 27/08/2018.
 */

import Foundation

import AsyncOperationResult
import SemiSingleton
import Vapor



public class ResetPasswordAction : Action<User, String, Void>, SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Container
	
	public let container: Container
	
	/* Sub-actions */
	public var resetLDAPPasswordAction: ResetLDAPPasswordAction
	public var resetGooglePasswordAction: ResetGooglePasswordAction
	
	public var ldapResetResult: AsyncOperationResult<Void>? {
		return resetLDAPPasswordAction.result
	}
	public var googleResetResult: AsyncOperationResult<Void>? {
		return resetGooglePasswordAction.result
	}
	
	var errors: [Error] {
		return [self.ldapResetResult?.error, self.googleResetResult?.error].compactMap{ $0 }
	}
	
	public required init(key u: User, additionalInfo: Container, store: SemiSingletonStore) {
		container = additionalInfo
		
		resetLDAPPasswordAction = store.semiSingleton(forKey: u, additionalInitInfo: additionalInfo)
		resetGooglePasswordAction = store.semiSingleton(forKey: u, additionalInitInfo: additionalInfo)
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (AsyncOperationResult<Void>) -> Void) throws {
		let operationQueue = try container.make(AsyncConfig.self).operationQueue
		
		let ldapOperation = AsyncBlockOperation{ endOperationBlock in
			self.resetLDAPPasswordAction.start(parameters: newPassword, weakeningMode: .alwaysInstantly, handler: { result in
				endOperationBlock()
			})
		}
		let googleOperation = AsyncBlockOperation{ endOperationBlock in
			self.resetGooglePasswordAction.start(parameters: newPassword, weakeningMode: .alwaysInstantly, handler: { result in
				endOperationBlock()
			})
		}
		
		let endOperation = BlockOperation{
			let errorCollection = ErrorCollection(self.errors)
			if errorCollection.errors.isEmpty {handler(.success(()))}
			else                              {handler(.error(errorCollection))}
		}
		endOperation.addDependency(ldapOperation)
		endOperation.addDependency(googleOperation)
		
		operationQueue.addOperations([ldapOperation, googleOperation, endOperation], waitUntilFinished: false)
	}
	
}
