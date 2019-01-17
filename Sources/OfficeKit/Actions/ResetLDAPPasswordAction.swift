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



public class ResetLDAPPasswordAction : Action<User, String, Void>, SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Container
	
	public let container: Container
	
	public required init(key u: User, additionalInfo: Container, store: SemiSingletonStore) {
		container = additionalInfo
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (AsyncOperationResult<Void>) -> Void) throws {
		guard let dn = subject.distinguishedName else {throw InvalidArgumentError(message: "Got a user with no DN; this is unsupported to reset the LDAP password.")}
		
		let dispatchQueue = try container.make(AsyncConfig.self).dispatchQueue
		let operationQueue = try container.make(AsyncConfig.self).operationQueue
		
		let officeKitConfig = try container.make(OfficeKitConfig.self)
		let singletonStore = try container.make(SemiSingletonStore.self)
		let connector = try singletonStore.semiSingleton(forKey: nil2throw(officeKitConfig.ldapConfig?.connectorSettings)) as LDAPConnector
		
		connector.connect(scope: (), handlerQueue: dispatchQueue, handler: { error in
			if let e = error {return handler(.error(e))}
			
			let person = LDAPInetOrgPerson(dn: dn.stringValue, sn: [], cn: [])
			person.userPassword = newPassword
			
			let operation = ModifyLDAPPasswordsOperation(users: [person], connector: connector)
			operation.completionBlock = {
				if let e = operation.errors[0] {handler(.error(e))}
				else                           {handler(.success(()))}
			}
			operationQueue.addOperations([operation], waitUntilFinished: false)
		})
	}
	
}
