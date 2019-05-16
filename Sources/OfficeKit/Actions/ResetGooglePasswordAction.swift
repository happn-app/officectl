/*
 * ResetGooglePasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/09/2018.
 */

import Foundation

import SemiSingleton
import Vapor

#if canImport(CommonCrypto)
	import CommonCrypto
#else
	import Crypto
#endif



public class ResetGooglePasswordAction : Action<User, String, Void>, SemiSingleton {
	
	public enum Error : Swift.Error {
		
		case noUsersFoundForEmail
		case tooManyUsersFoundForEmail
		
	}
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Container
	
	public let container: Container
	
	/* Contains the Google user id as soon as the user is found (after the
	 * operation is started). */
	public var googleUserId: String?
	
	public required init(key u: User, additionalInfo: Container, store: SemiSingletonStore) {
		container = additionalInfo
		
		super.init(subject: u)
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
		
		let asyncConfig = try container.make(AsyncConfig.self)
		let singletonStore = try container.make(SemiSingletonStore.self)
		
		let googleSettings = try container.make(OfficeKitConfig.self).googleConfigOrThrow()
		let connector = try singletonStore.semiSingleton(forKey: googleSettings.connectorSettings) as GoogleJWTConnector
		
		let f = try connector
		.connect(scope: Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user"), asyncConfig: asyncConfig)
		.and(subject.existingGoogleUser(container: container))
		.thenThrowing{ (_, googleUser) -> GoogleUser in
			let u = try nil2throw(googleUser, "No Google user found for given user")
			self.googleUserId = u.id /* We set the user id as soon as we have it. */
			return u
		}
		.then{ googleUser -> Future<Void> in
			var googleUser = googleUser
			
			googleUser.password = newPasswordHash.reduce("", { $0 + String(format: "%02x", $1) })
			googleUser.hashFunction = .sha1
			googleUser.changePasswordAtNextLogin = false
			
			let modifyUserOperation = ModifyGoogleUserOperation(user: googleUser, propertiesToUpdate: Set(arrayLiteral: .hashFunction, .password, .changePasswordAtNextLogin), connector: connector)
			return asyncConfig.eventLoop.future(from: modifyUserOperation, queue: asyncConfig.operationQueue)
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
	
}
