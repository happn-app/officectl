/*
 *  AnyDirectoryService.swift
 *  OfficeKit
 *
 *  Created by François Lamboley on 27/06/2019.
 */

import Foundation

import Action
import Async



private protocol DirectoryServiceBox {
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction<UserType : Hashable>(for user: UserType) throws -> Action<UserType, String, Void>
	
	func existingUserId<UserType : Hashable>(from email: Email) throws -> Future<UserType?>
	func existingUserId<T : DirectoryService, UserType : Hashable>(from user: T.UserType, in service: T) throws -> Future<UserType?>
	
}

private struct ConcreteDirectoryBox<Base : DirectoryService> : DirectoryServiceBox {
	
	let originalValue: Base
	
	var supportsPasswordChange: Bool {return originalValue.supportsPasswordChange}
	func changePasswordAction<UserType : Hashable>(for user: UserType) throws -> Action<UserType, String, Void> {
		guard let u = user as? Base.UserType else {
			throw InvalidArgumentError(message: "Got invalid user type (\(UserType.self)) to retrieve password action for directory service of type \(Base.self)")
		}
		/* We know the returned action by the original service will have the
		 * expected type because of the protocol requirements; we can force cast. */
		return try originalValue.changePasswordAction(for: u) as! Action<UserType, String, Void>
	}
	
	func existingUserId<UserType : Hashable>(from email: Email) throws -> Future<UserType?> {
		guard let f = originalValue.existingUserId(from: email) as? Future<UserType?> else {
			throw InvalidArgumentError(message: "Got invalid user type (\(UserType.self)) for retreiving existing user id for directory service of type \(Base.self)")
		}
		return f
	}
	
	func existingUserId<T : DirectoryService, UserType : Hashable>(from user: T.UserType, in service: T) throws -> Future<UserType?> {
		guard let f = originalValue.existingUserId(from: user, in: service) as? Future<UserType?> else {
			throw InvalidArgumentError(message: "Got invalid user type (\(UserType.self)) for retreiving existing user id for directory service of type \(Base.self)")
		}
		return f
	}
	
}

public struct AnyDirectoryService : DirectoryService {
	
	public typealias UserType = AnyHashable
	
	init<T : DirectoryService>(_ object: T) {
		box = ConcreteDirectoryBox(originalValue: object)
	}
	
	public var supportsPasswordChange: Bool {
		return box.supportsPasswordChange
	}
	
	public func existingUserId(from email: Email) -> Future<AnyHashable?> {
		return box.existingUserId(from: <#T##Email#>)
	}
	
//	public func changePasswordAction<UserType>(for user: UserType) throws -> Action<UserType, String, Void> where UserType : Hashable {
//		return try box.changePasswordAction(for: user)
//	}
//
//	public func existingUserId<UserType>(from email: Email) throws -> Future<UserType?> where UserType : Hashable {
//		return try box.existingUserId(from: email)
//	}
//
//	public func existingUserId<T, UserType>(from user: T.UserType, in service: T) throws -> Future<UserType?> where T : DirectoryService, UserType : Hashable {
//		return try box.existingUserId(from: user, in: service)
//	}

	private let box: DirectoryServiceBox
	
}
