/*
 * ResetLDAPPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/11/2018.
 */

import Foundation

import AsyncOperationResult
import SemiSingleton
import Vapor



public class ResetLDAPPasswordAction : Action<ResetPasswordActionConfig, Void>, SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public let user: User
	public private(set) var newPassword: String?
	
	public required init(key u: User, additionalInfo: Void, store: SemiSingletonStore) {
		user = u
		newPassword = nil
	}
	
	public override func unsafeStart(config: ResetPasswordActionConfig, handler: @escaping (AsyncOperationResult<Void>) -> Void) throws {
		guard let dn = user.distinguishedName else {return handler(.error(InvalidArgumentError(message: "Got a user with no DN; this is unsupported to reset the LDAP password.")))}
		
		let (p, container) = config
		let dispatchQueue = try container.make(AsyncConfig.self).dispatchQueue
		let operationQueue = try container.make(AsyncConfig.self).operationQueue
		
		let officeKitConfig = try container.make(OfficeKitConfig.self)
		let singletonStore = try container.make(SemiSingletonStore.self)
		let connector = try singletonStore.semiSingleton(forKey: nil2throw(officeKitConfig.ldapConfig?.connectorSettings)) as LDAPConnector
		
		newPassword = p
		
		connector.connect(scope: (), handlerQueue: dispatchQueue, handler: { error in
			if let e = error {return handler(.error(e))}
			
			let person = LDAPInetOrgPerson(dn: dn.stringValue, sn: [], cn: [])
			person.userPassword = self.newPassword
			
			let operation = ModifyLDAPPasswordsOperation(users: [person], connector: connector)
			operation.completionBlock = {
				if let e = operation.errors[0] {handler(.error(e))}
				else                           {handler(.success(()))}
			}
			operationQueue.addOperations([operation], waitUntilFinished: false)
		})
	}
	
}
