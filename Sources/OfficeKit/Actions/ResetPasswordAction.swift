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



public typealias ResetPasswordActionConfig = (newPassword: String, container: Container)
public class ResetPasswordAction : Action<ResetPasswordActionConfig, Void>, SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public let user: User
	public private(set) var newPassword: String?
	
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
		return [self.ldapResetResult?.error].compactMap{ $0 }
	}
	
	public required init(key u: User, additionalInfo: Void, store: SemiSingletonStore) {
		user = u
		newPassword = nil
		
		resetLDAPPasswordAction = store.semiSingleton(forKey: u)
		resetGooglePasswordAction = store.semiSingleton(forKey: u)
	}
	
	public override func unsafeStart(config: ResetPasswordActionConfig, handler: @escaping (AsyncOperationResult<Void>) -> Void) throws {
		let (p, container) = config
		let operationQueue = try container.make(AsyncConfig.self).operationQueue
		
		newPassword = p
		
		let ldapOperation = AsyncBlockOperation{ endOperationBlock in
			self.resetLDAPPasswordAction.start(config: config, weakeningDelay: nil, handler: { result in
				endOperationBlock()
			})
		}
		let googleOperation = AsyncBlockOperation{ endOperationBlock in
			self.resetGooglePasswordAction.start(config: config, weakeningDelay: nil, handler: { result in
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
