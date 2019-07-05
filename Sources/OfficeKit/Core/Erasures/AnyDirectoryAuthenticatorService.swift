/*
 * AnyDirectoryAuthenticatorService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/06/2019.
 */

import Foundation

import Async



private protocol DirectoryAuthenticatorServiceBox {
	
	func authenticate<UserIdType : Hashable, AuthenticationChallenge>(userId: UserIdType, challenge: AuthenticationChallenge) throws -> Future<Bool>
	func isUserIdOfAnAdmin<UserIdType : Hashable>(_ userId: UserIdType) throws -> Future<Bool>
	
}

private struct ConcreteDirectoryAuthenticatorBox<Base : DirectoryAuthenticatorService> : DirectoryAuthenticatorServiceBox {
	
	let originalAuthenticator: Base
	
	func authenticate<UserIdType : Hashable, AuthenticationChallenge>(userId: UserIdType, challenge: AuthenticationChallenge) throws -> Future<Bool> {
		guard let uid = userId as? Base.UserType.IdType, let c = challenge as? Base.AuthenticationChallenge else {
			throw InvalidArgumentError(message: "Got invalid user id type (\(UserIdType.self)) or auth challenge type (\(AuthenticationChallenge.self)) to authenticate with a directory service authenticator of type \(Base.self)")
		}
		return originalAuthenticator.authenticate(userId: uid, challenge: c)
	}
	
	func isUserIdOfAnAdmin<UserIdType : Hashable>(_ userId: UserIdType) throws -> Future<Bool> {
		guard let uid = userId as? Base.UserType.IdType else {
			throw InvalidArgumentError(message: "Got invalid user id type (\(UserIdType.self)) to check if user is admin with a directory service authenticator of type \(Base.self)")
		}
		return originalAuthenticator.isUserIdOfAnAdmin(uid)
	}
	
}

public class AnyDirectoryAuthenticatorService : AnyDirectoryService, DirectoryAuthenticatorService {
	
	public typealias UserIdType = AnyHashable
	public typealias AuthenticationChallenge = Any
	
	override init<T : DirectoryAuthenticatorService>(_ object: T, asyncConfig a: AsyncConfig) {
		box = ConcreteDirectoryAuthenticatorBox(originalAuthenticator: object)
		super.init(object, asyncConfig: a)
	}
	
	public override func unwrapped<DirectoryType : DirectoryAuthenticatorService>() -> DirectoryType? {
		return (box as? ConcreteDirectoryAuthenticatorBox<DirectoryType>)?.originalAuthenticator ?? (box as? ConcreteDirectoryAuthenticatorBox<AnyDirectoryAuthenticatorService>)?.originalAuthenticator.unwrapped()
	}
	
	public func authenticate(userId: AnyHashable, challenge: Any) -> Future<Bool> {
		do    {return try box.authenticate(userId: userId, challenge: challenge)}
		catch {return asyncConfig.eventLoop.newFailedFuture(error: error)}
	}
	
	public func isUserIdOfAnAdmin(_ userId: AnyHashable) -> EventLoopFuture<Bool> {
		do    {return try box.isUserIdOfAnAdmin(userId)}
		catch {return asyncConfig.eventLoop.newFailedFuture(error: error)}
	}
	
	private let box: DirectoryAuthenticatorServiceBox
	
}
