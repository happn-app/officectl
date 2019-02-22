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
	public let resetLDAPPasswordAction: ResetLDAPPasswordAction
	public let resetGooglePasswordAction: ResetGooglePasswordAction
	
	public private(set) var ldapResetResult: AsyncOperationResult<Void>?
	public private(set) var googleResetResult: AsyncOperationResult<Void>?
	
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
		
		ldapResetResult = nil
		let ldapOperation = AsyncBlockOperation{ endOperationBlock in
			self.resetLDAPPasswordAction.start(parameters: newPassword, weakeningMode: .alwaysInstantly, handler: { result in
				self.ldapResetResult = result
				endOperationBlock()
			})
		}
		googleResetResult = nil
		let googleOperation = AsyncBlockOperation{ endOperationBlock in
			self.resetGooglePasswordAction.start(parameters: newPassword, weakeningMode: .alwaysInstantly, handler: { result in
				self.googleResetResult = result
				endOperationBlock()
			})
		}
		let resetOperations = [ldapOperation, googleOperation]
		
		let endOperation = BlockOperation{
			let errorCollection = ErrorCollection(self.errors)
			if errorCollection.errors.isEmpty {handler(.success(()))}
			else                              {handler(.error(errorCollection))}
		}
		resetOperations.forEach{ endOperation.addDependency($0) }
		
		operationQueue.addOperations(resetOperations + [endOperation], waitUntilFinished: false)
	}
	
}
