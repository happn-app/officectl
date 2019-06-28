/*
 * AnyDirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/06/2019.
 */

import Foundation

import Async



private protocol DirectoryAuthenticatorServiceBox {
	
	func authenticate<UserIdType : Hashable, AuthenticationChallenge>(user: UserIdType, challenge: AuthenticationChallenge) throws -> Future<Bool>
	func isUserAdmin<UserIdType : Hashable>(_ user: UserIdType) throws -> Future<Bool>
	
}

private struct ConcreteDirectoryAuthenticatorBox<Base : DirectoryAuthenticatorService> : DirectoryAuthenticatorServiceBox {
	
	let originalAuthenticator: Base
	
	func authenticate<UserIdType : Hashable, AuthenticationChallenge>(user: UserIdType, challenge: AuthenticationChallenge) throws -> Future<Bool> {
		guard let u = user as? Base.UserIdType, let c = challenge as? Base.AuthenticationChallenge else {
			throw InvalidArgumentError(message: "Got invalid user type (\(UserIdType.self)) or auth challenge type (\(AuthenticationChallenge.self)) to authenticate with a directory service authenticator of type \(Base.self)")
		}
		return originalAuthenticator.authenticate(user: u, challenge: c)
	}
	
	func isUserAdmin<UserIdType : Hashable>(_ user: UserIdType) throws -> Future<Bool> {
		guard let u = user as? Base.UserIdType else {
			throw InvalidArgumentError(message: "Got invalid user type (\(UserIdType.self)) to check if user is admin with a directory service authenticator of type \(Base.self)")
		}
		return originalAuthenticator.isUserAdmin(u)
	}
	
}

public struct AnyDirectoryAuthenticatorService : DirectoryAuthenticatorService {
	
	public typealias UserIdType = AnyHashable
	public typealias AuthenticationChallenge = Any
	
	public let asyncConfig: AsyncConfig
	
	init<T : DirectoryAuthenticatorService>(_ object: T, asyncConfig a: AsyncConfig) {
		box = ConcreteDirectoryAuthenticatorBox(originalAuthenticator: object)
		asyncConfig = a
	}
	
	public func unwrapped<DirectoryType : DirectoryAuthenticatorService>() -> DirectoryType? {
		return (box as? ConcreteDirectoryAuthenticatorBox<DirectoryType>)?.originalAuthenticator
	}
	
	public func authenticate(user: AnyHashable, challenge: Any) -> Future<Bool> {
		do    {return try box.authenticate(user: user, challenge: challenge)}
		catch {return asyncConfig.eventLoop.newFailedFuture(error: error)}
	}
	
	public func isUserAdmin(_ user: AnyHashable) -> EventLoopFuture<Bool> {
		do    {return try box.isUserAdmin(user)}
		catch {return asyncConfig.eventLoop.newFailedFuture(error: error)}
	}
	
	private let box: DirectoryAuthenticatorServiceBox
	
}
