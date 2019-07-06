/*
 * ResetGooglePasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/09/2018.
 */

import Foundation

import SemiSingleton
import Service

#if canImport(CommonCrypto)
	import CommonCrypto
#else
	import Crypto
#endif



public class ResetGooglePasswordAction : Action<GoogleUser, String, Void>, ResetPasswordAction, SemiSingleton {
	
	public static func additionalInfo(from container: Container) throws -> (AsyncConfig, GoogleJWTConnector) {
		return try (container.make(), container.make(SemiSingletonStore.self).semiSingleton(forKey: container.make()))
	}
	
	public typealias SemiSingletonKey = GoogleUser
	public typealias SemiSingletonAdditionalInitInfo = (AsyncConfig, GoogleJWTConnector)
	
	/* Contains the Google user id as soon as the user is found (after the
	 * operation is started). */
	public var googleUserId: String?
	
	public required init(key id: GoogleUser, additionalInfo: (AsyncConfig, GoogleJWTConnector), store: SemiSingletonStore) {
		deps = Dependencies(asyncConfig: additionalInfo.0, connector: additionalInfo.1)
		
		super.init(subject: id)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (Result<Void, Swift.Error>) -> Void) throws {
		googleUserId = nil /* We re-search for the user, so we clear the current user id we have */
		
		let newPasswordHash: Data
		let passwordData = Data(newPassword.utf8)
		#if canImport(CommonCrypto)
			var sha1 = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
			passwordData.withUnsafeBytes{ (passwordDataBytes: UnsafeRawBufferPointer) in
				let passwordDataBytes = passwordDataBytes.bindMemory(to: UInt8.self).baseAddress!
				sha1.withUnsafeMutableBytes{ (sha1Bytes: UnsafeMutableRawBufferPointer) in
					let sha1Bytes = sha1Bytes.bindMemory(to: UInt8.self).baseAddress!
					/* The call below should returns sha1Bytes (says the man). */
					_ = CC_SHA1(passwordDataBytes, CC_LONG(passwordData.count), sha1Bytes)
				}
			}
			newPasswordHash = sha1
		#else
			newPasswordHash = try SHA1.hash(passwordData)
		#endif
		
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		
		let f = deps.connector.connect(scope: Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user"), eventLoop: eventLoop)
		.then{ googleUser -> Future<Void> in
			var googleUser = self.subject
			
			googleUser.password = newPasswordHash.reduce("", { $0 + String(format: "%02x", $1) })
			googleUser.hashFunction = .sha1
			googleUser.changePasswordAtNextLogin = false
			
			let modifyUserOperation = ModifyGoogleUserOperation(user: googleUser, propertiesToUpdate: Set(arrayLiteral: .hashFunction, .password, .changePasswordAtNextLogin), connector: self.deps.connector)
			return Future<Void>.future(from: modifyUserOperation, eventLoop: eventLoop)
		}
		f.whenSuccess{ _ in
			/* Success! Let’s call the handler. */
			handler(.success(()))
		}
		f.whenFailure{ error in
			/* Error. Let’s call the handler. */
			handler(.failure(error))
		}
	}
	
	private struct Dependencies {
		
		var asyncConfig: AsyncConfig
		var connector: GoogleJWTConnector
		
	}
	
	private let deps: Dependencies
	
}
