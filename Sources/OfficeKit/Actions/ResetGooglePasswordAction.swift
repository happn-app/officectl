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



public class ResetGooglePasswordAction : Action<User, String, Void>, SemiSingleton {
	
	public enum Error : Swift.Error {
		
		case noUsersFoundForEmail
		case tooManyUsersFoundForEmail
		
	}
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Container
	
	public let container: Container
	
	public required init(key u: User, additionalInfo: Container, store: SemiSingletonStore) {
		container = additionalInfo
		
		super.init(subject: u)
	}
	
	public override func unsafeStart(parameters newPassword: String, handler: @escaping (AsyncOperationResult<Void>) -> Void) throws {
		guard let email = subject.email else {return handler(.error(InvalidArgumentError(message: "Got a user with no email; this is unsupported to reset the Google password.")))}
		
		let asyncConfig = try container.make(AsyncConfig.self)
		let singletonStore = try container.make(SemiSingletonStore.self)
		
		let googleSettings = try container.make(OfficeKitConfig.self).googleConfigOrThrow()
		let connector = try singletonStore.semiSingleton(forKey: googleSettings.connectorSettings) as GoogleJWTConnector
		
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
			let passwordData = Data(newPassword.utf8)
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
