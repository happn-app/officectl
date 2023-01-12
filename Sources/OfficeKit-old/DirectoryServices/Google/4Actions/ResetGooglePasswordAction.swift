/*
 * ResetGooglePasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/18.
 */

import Foundation

import Crypto
import NIO
import SemiSingleton
import ServiceKit



public final class ResetGooglePasswordAction : Action<GoogleUser, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public static func additionalInfo(from services: Services) throws -> GoogleJWTConnector {
		return try (services.semiSingleton(forKey: services.make()))
	}
	
	public typealias SemiSingletonKey = GoogleUser
	public typealias SemiSingletonAdditionalInitInfo = GoogleJWTConnector
	
	public required init(key id: GoogleUser, additionalInfo: GoogleJWTConnector, store: SemiSingletonStore) {
		deps = Dependencies(connector: additionalInfo)
		
		super.init(subject: id)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Swift.Error>) -> Void) throws {
		Task{await handler(Result{
			try await deps.connector.connect(ModifyGoogleUserOperation.scopes)
			
			var googleUser = self.subject.cloneForPatching()
			googleUser.password = Insecure.SHA1.hash(data: Data(newPassword.utf8)).reduce("", { $0 + String(format: "%02x", $1) })
			googleUser.hashFunction = .sha1
			googleUser.changePasswordAtNextLogin = false
			
			let modifyUserOperation = ModifyGoogleUserOperation(user: googleUser, connector: self.deps.connector)
			/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
			try await modifyUserOperation.startAndGetResult()
		})}
	}
	
	private struct Dependencies {
		
		var connector: GoogleJWTConnector
		
	}
	
	private let deps: Dependencies
	
}
