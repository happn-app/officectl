/*
 * AnyDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 27/06/2019.
 */

import Foundation

import Async
import Vapor



private protocol DirectoryServiceBox {
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction<UserIdType : Hashable>(for user: UserIdType) throws -> ResetPasswordAction
	
	func existingUserId(from email: Email) -> Future<AnyHashable?>
	func existingUserId<T : DirectoryService>(from user: T.UserIdType, in service: T) -> Future<AnyHashable?>
	
}

private struct ConcreteDirectoryBox<Base : DirectoryService> : DirectoryServiceBox {
	
	let originalDirectory: Base
	
	var supportsPasswordChange: Bool {return originalDirectory.supportsPasswordChange}
	
	func changePasswordAction<UserIdType : Hashable>(for user: UserIdType) throws -> ResetPasswordAction {
		guard let u = user as? Base.UserIdType else {
			throw InvalidArgumentError(message: "Got invalid user type (\(UserIdType.self)) to retrieve password action for directory service of type \(Base.self)")
		}
		return try originalDirectory.changePasswordAction(for: u)
	}
	
	func existingUserId(from email: Email) -> Future<AnyHashable?> {
		return originalDirectory.existingUserId(from: email).map{ $0.flatMap{ AnyHashable($0) } }
	}
	
	func existingUserId<T : DirectoryService>(from user: T.UserIdType, in service: T) -> Future<AnyHashable?> {
		return originalDirectory.existingUserId(from: user, in: service).map{ $0.flatMap{ AnyHashable($0) } }
	}
	
}

public struct AnyDirectoryService : DirectoryService {
	
	public typealias ConfigType = AnyOfficeKitServiceConfig
	public typealias UserIdType = AnyHashable
	
	public let asyncConfig: AsyncConfig
	
	init<T : DirectoryService>(_ object: T, asyncConfig a: AsyncConfig) {
		box = ConcreteDirectoryBox(originalDirectory: object)
		asyncConfig = a
	}
	
	public func unwrapped<DirectoryType : DirectoryService>() -> DirectoryType? {
		return (box as? ConcreteDirectoryBox<DirectoryType>)?.originalDirectory
	}
	
	public var supportsPasswordChange: Bool {
		return box.supportsPasswordChange
	}
	
	public func existingUserId(from email: Email) -> Future<AnyHashable?> {
		return box.existingUserId(from: email)
	}
	
	public func existingUserId<T : DirectoryService>(from userId: T.UserIdType, in service: T) -> Future<AnyHashable?> {
		return box.existingUserId(from: userId, in: service)
	}
	
	public func changePasswordAction(for user: AnyHashable) throws -> ResetPasswordAction {
		return try box.changePasswordAction(for: user)
	}
	
	private let box: DirectoryServiceBox
	
}
