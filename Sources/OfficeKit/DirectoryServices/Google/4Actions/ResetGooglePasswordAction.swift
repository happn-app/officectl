/*
 * ResetGooglePasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/09/2018.
 */

import Foundation

import Crypto
import NIO
import SemiSingleton
import ServiceKit



public class ResetGooglePasswordAction : Action<GoogleUser, String, Void>, ResetPasswordAction, SemiSingleton {
	
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
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		
		let f = deps.connector.connect(scope: ModifyGoogleUserOperation.scopes, eventLoop: eventLoop)
		.map{ _ -> EventLoopFuture<Void> in
			var googleUser = self.subject.cloneForPatching()
			
			let passwordSHA1 = Insecure.SHA1.hash(data: Data(newPassword.utf8)).reduce("", { $0 + String(format: "%02x", $1) })
			googleUser.password = .set(passwordSHA1)
			googleUser.hashFunction = .set(.sha1)
			googleUser.changePasswordAtNextLogin = .set(false)
			
			let modifyUserOperation = ModifyGoogleUserOperation(user: googleUser, connector: self.deps.connector)
			return EventLoopFuture<Void>.future(from: modifyUserOperation, on: eventLoop)
		}
		
		f.whenSuccess{ _   in handler(.success(())) }
		f.whenFailure{ err in handler(.failure(err)) }
	}
	
	private struct Dependencies {
		
		var connector: GoogleJWTConnector
		
	}
	
	private let deps: Dependencies
	
}
