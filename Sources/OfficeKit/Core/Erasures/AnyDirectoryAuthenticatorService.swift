/*
 * AnyDirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/06/2019.
 */

import Foundation

import Async
import Service



private protocol DirectoryAuthenticatorServiceBox {
	
	func authenticate<UserIdType : Hashable, AuthenticationChallenge>(userId: UserIdType, challenge: AuthenticationChallenge, on container: Container) throws -> Future<Bool>
	func validateAdminStatus<UserIdType : Hashable>(userId: UserIdType, on container: Container) throws -> Future<Bool>
	
}

private struct ConcreteDirectoryAuthenticatorBox<Base : DirectoryAuthenticatorService> : DirectoryAuthenticatorServiceBox {
	
	let originalAuthenticator: Base
	
	func authenticate<UserIdType : Hashable, AuthenticationChallenge>(userId: UserIdType, challenge: AuthenticationChallenge, on container: Container) throws -> Future<Bool> {
		guard let uid = userId as? Base.UserType.UserIdType, let c = challenge as? Base.AuthenticationChallenge else {
			throw InvalidArgumentError(message: "Got invalid user id type (\(UserIdType.self)) or auth challenge type (\(AuthenticationChallenge.self)) to authenticate with a directory service authenticator of type \(Base.self)")
		}
		return try originalAuthenticator.authenticate(userId: uid, challenge: c, on: container)
	}
	
	func validateAdminStatus<UserIdType : Hashable>(userId: UserIdType, on container: Container) throws -> Future<Bool> {
		guard let uid = userId as? Base.UserType.UserIdType else {
			throw InvalidArgumentError(message: "Got invalid user id type (\(UserIdType.self)) to check if user is admin with a directory service authenticator of type \(Base.self)")
		}
		return try originalAuthenticator.validateAdminStatus(userId: uid, on: container)
	}
	
}

public class AnyDirectoryAuthenticatorService : AnyDirectoryService, DirectoryAuthenticatorService {
	
	public typealias AuthenticationChallenge = Any
	
	override init<T : DirectoryAuthenticatorService>(_ object: T) {
		box = ConcreteDirectoryAuthenticatorBox(originalAuthenticator: object)
		super.init(object)
	}
	
	public func authenticate(userId: AnyHashable, challenge: Any, on container: Container) throws -> Future<Bool> {
		return try box.authenticate(userId: userId, challenge: challenge, on: container)
	}
	
	public func validateAdminStatus(userId: AnyHashable, on container: Container) throws -> Future<Bool> {
		return try box.validateAdminStatus(userId: userId, on: container)
	}
	
	fileprivate let box: DirectoryAuthenticatorServiceBox
	
}


extension DirectoryAuthenticatorService {
	
	public func erased() -> AnyDirectoryAuthenticatorService {
		if let erased = self as? AnyDirectoryAuthenticatorService {
			return erased
		}
		
		return AnyDirectoryAuthenticatorService(self)
	}
	
	public func unboxed<DirectoryType : DirectoryAuthenticatorService>() -> DirectoryType? {
		guard let anyAuth = self as? AnyDirectoryAuthenticatorService else {
			/* Nothing to unbox, just return self */
			return self as? DirectoryType
		}
		
		return (anyAuth.box as? ConcreteDirectoryAuthenticatorBox<DirectoryType>)?.originalAuthenticator ?? (anyAuth.box as? ConcreteDirectoryAuthenticatorBox<AnyDirectoryAuthenticatorService>)?.originalAuthenticator.unboxed()
	}
	
}
