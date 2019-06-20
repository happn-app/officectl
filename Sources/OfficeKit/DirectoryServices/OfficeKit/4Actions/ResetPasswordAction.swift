/*
 * ResetPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 27/08/2018.
 */

import Foundation

import SemiSingleton
import Vapor



public class ResetPasswordAction : Action<User, String, Void>, SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Container
	
	public let container: Container
	
	/* Sub-actions */
	public let resetLDAPPasswordAction: ResetLDAPPasswordAction
	public let resetGooglePasswordAction: ResetGooglePasswordAction
	#if canImport(DirectoryService) && canImport(OpenDirectory)
	public let resetOpenDirectoryPasswordAction: ResetOpenDirectoryPasswordAction
	#endif
	
	public private(set) var ldapResetResult: Result<Void, Error>?
	public private(set) var googleResetResult: Result<Void, Error>?
	public private(set) var openDirectoryResetResult: Result<Void, Error>?
	
	var errors: [Error] {
		return [self.ldapResetResult?.failureValue, self.googleResetResult?.failureValue, self.openDirectoryResetResult?.failureValue].compactMap{ $0 }
	}
	
	public required init(key u: User, additionalInfo: Container, store: SemiSingletonStore) {
		container = additionalInfo
		
		resetLDAPPasswordAction = store.semiSingleton(forKey: u, additionalInitInfo: additionalInfo)
		resetGooglePasswordAction = store.semiSingleton(forKey: u, additionalInitInfo: additionalInfo)
		#if canImport(DirectoryService) && canImport(OpenDirectory)
		resetOpenDirectoryPasswordAction = store.semiSingleton(forKey: u, additionalInitInfo: additionalInfo)
		#endif
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Error>) -> Void) throws {
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
		#if canImport(DirectoryService) && canImport(OpenDirectory)
		openDirectoryResetResult = nil
		let resetOpenDirectoryOperation = AsyncBlockOperation{ endOperationBlock in
			self.resetOpenDirectoryPasswordAction.start(parameters: newPassword, weakeningMode: .alwaysInstantly, handler: { result in
				self.openDirectoryResetResult = result
				endOperationBlock()
			})
		}
		#else
		let resetOpenDirectoryOperation = AsyncBlockOperation{ endOperationBlock in
			self.openDirectoryResetResult = .failure(NotAvailableOnThisPlatformError())
		}
		#endif
		let resetOperations = [ldapOperation, googleOperation, resetOpenDirectoryOperation]
		
		let endOperation = BlockOperation{
			let errorCollection = ErrorCollection(self.errors)
			if errorCollection.errors.isEmpty {handler(.success(()))}
			else                              {handler(.failure(errorCollection))}
		}
		resetOperations.forEach{ endOperation.addDependency($0) }
		
		operationQueue.addOperations(resetOperations + [endOperation], waitUntilFinished: false)
	}
	
}
