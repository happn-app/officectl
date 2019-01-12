/*
 * ResetGooglePasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/09/2018.
 */

import Foundation

import AsyncOperationResult
import SemiSingleton
import Vapor

#if canImport(CommonCrypto)
	import CommonCrypto
#elseif canImport(CCommonCrypto)
	import CCommonCrypto
#else
	import Crypto
#endif



public class ResetGooglePasswordAction : Action<ResetPasswordActionConfig, Void>, SemiSingleton {
	
	public enum Error : Swift.Error {
		
		case noUsersFoundForEmail
		case tooManyUsersFoundForEmail
		
	}
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public let user: User
	public private(set) var newPassword: String?
	
	public required init(key u: User, additionalInfo: Void, store: SemiSingletonStore) {
		user = u
		newPassword = nil
	}
	
	public override func unsafeStart(config: ResetPasswordActionConfig, handler: @escaping (AsyncOperationResult<Void>) -> Void) throws {
		guard let email = user.email else {return handler(.error(InvalidArgumentError(message: "Got a user with no email; this is unsupported to reset the Google password.")))}
		
		let (p, container) = config
		let asyncConfig = try container.make(AsyncConfig.self)
		let singletonStore = try container.make(SemiSingletonStore.self)
		
		let googleSettings = try container.make(OfficeKitConfig.self).googleConfigOrThrow()
		let connector = try singletonStore.semiSingleton(forKey: googleSettings.connectorSettings) as GoogleJWTConnector
		
		newPassword = p
		
		let f = connector
		.connect(scope: Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.user"), asyncConfig: asyncConfig)
		.then{ _ -> Future<[GoogleUser]> in
			let findUserOperation = SearchGoogleUsersOperation(searchedDomain: email.domain, query: "email=\(email.stringValue)", googleConnector: connector)
			return asyncConfig.eventLoop.future(from: findUserOperation, queue: asyncConfig.operationQueue)
		}
		.map{ users -> GoogleUser in
			guard var user = users.first else {throw Error.noUsersFoundForEmail}
			guard users.count == 1 else {throw Error.tooManyUsersFoundForEmail}
			
			let digest: Data
			let passwordData = Data(p.utf8)
			#if canImport(CommonCrypto) || canImport(CCommonCrypto)
				var sha1 = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
				passwordData.withUnsafeBytes{ (passwordDataBytes: UnsafePointer<UInt8>) in
					sha1.withUnsafeMutableBytes{ (sha1Bytes: UnsafeMutablePointer<UInt8>) in
						/* The call below should returns sha1Bytes (says the man). */
						_ = CC_SHA1(passwordDataBytes, CC_LONG(passwordData.count), sha1Bytes)
					}
				}
				digest = sha1
			#else
				digest = try SHA1.hash(passwordData)
			#endif
			user.password = digest.reduce("", { $0 + String(format: "%02x", $1) })
			user.hashFunction = .sha1
			user.changePasswordAtNextLogin = false
			
			return user
		}
		.then{ user -> Future<Void> in
			let modifyUserOperation = ModifyGoogleUserOperation(user: user, propertiesToUpdate: Set(arrayLiteral: "hashFunction", "password", "changePasswordAtNextLogin"), connector: connector)
			return asyncConfig.eventLoop.future(from: modifyUserOperation, queue: asyncConfig.operationQueue)
		}
		f.whenSuccess{ _ in
			/* Success! Let’s call the handler. */
			handler(.success(()))
		}
		f.whenFailure{ error in
			/* Error. Let’s call the handler. */
			handler(.error(error))
		}
	}
	
}
