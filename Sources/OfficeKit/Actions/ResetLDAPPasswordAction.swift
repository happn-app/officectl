/*
 * ResetLDAPPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/11/2018.
 */

import Foundation

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
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Error>) -> Void) throws {
		guard let dn = subject.distinguishedName else {throw InvalidArgumentError(message: "Got a user with no DN; this is unsupported to reset the LDAP password.")}
		
		let dispatchQueue = try container.make(AsyncConfig.self).dispatchQueue
		let operationQueue = try container.make(AsyncConfig.self).operationQueue
		
		let officeKitConfig = try container.make(OfficeKitConfig.self)
		let singletonStore = try container.make(SemiSingletonStore.self)
		let connector = try singletonStore.semiSingleton(forKey: nil2throw(officeKitConfig.ldapConfig?.connectorSettings)) as LDAPConnector
		
		/* Note: To be symmetrical with the reset google user action, we could use
		 *       the existingLDAPUser method. */
		connector.connect(scope: (), handlerQueue: dispatchQueue, handler: { _, error in
			if let e = error {return handler(.failure(e))}
			
			let person = LDAPInetOrgPerson(dn: dn.stringValue, sn: [], cn: [])
			person.userPassword = newPassword
			
			let operation = ModifyLDAPPasswordsOperation(users: [person], connector: connector)
			operation.completionBlock = {
				if let e = operation.errors[0] {handler(.failure(e))}
				else                           {handler(.success(()))}
			}
			operationQueue.addOperations([operation], waitUntilFinished: false)
		})
	}
	
}
