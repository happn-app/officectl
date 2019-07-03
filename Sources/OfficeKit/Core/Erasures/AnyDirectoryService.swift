/*
 * AnyDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 27/06/2019.
 */

import Foundation

import Async



private protocol DirectoryServiceBox {
	
	var config: AnyOfficeKitServiceConfig {get}
	
	func logicalUser(from email: Email) throws -> AnyDirectoryUser?
	func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, eventLoop: EventLoop) throws -> AnyDirectoryUser?
	
	func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<AnyDirectoryUser?>
	func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, eventLoop: EventLoop) -> Future<AnyDirectoryUser?>
	
	func listAllUsers() -> Future<[AnyDirectoryUser]>
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: AnyDirectoryUser, eventLoop: EventLoop) -> Future<AnyDirectoryUser>
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, eventLoop: EventLoop) -> Future<AnyDirectoryUser>
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: AnyDirectoryUser, eventLoop: EventLoop) -> Future<Void>
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: AnyDirectoryUser) throws -> ResetPasswordAction
	
}

private struct ConcreteDirectoryBox<Base : DirectoryService> : DirectoryServiceBox {
	
	let originalDirectory: Base
	
	var config: AnyOfficeKitServiceConfig {
		return originalDirectory.config.erased()
	}
	
	func logicalUser(from email: Email) throws -> AnyDirectoryUser? {
		return try originalDirectory.logicalUser(from: email)?.erased()
	}
	
	func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, eventLoop: EventLoop) throws -> AnyDirectoryUser? {
		guard let anyService = service as? AnyDirectoryService else {
			return try originalDirectory.logicalUser(from: user, in: service)?.erased()
		}
		
		let anyUser = user as! AnyDirectoryUser
		if let (service, user): (GitHubService, GitHubService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try logicalUser(from: user, in: service, eventLoop: eventLoop)
		}
		if let (service, user): (GoogleService, GoogleService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try logicalUser(from: user, in: service, eventLoop: eventLoop)
		}
		if let (service, user): (LDAPService, LDAPService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try logicalUser(from: user, in: service, eventLoop: eventLoop)
		}
		if let (service, user): (OpenDirectoryService, OpenDirectoryService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try logicalUser(from: user, in: service, eventLoop: eventLoop)
		}
		
		throw InvalidArgumentError(message: "Unknown AnyDirectory for getting existing user in type erased directory service.")
	}
	
	func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<AnyDirectoryUser?> {
		return originalDirectory.existingUser(from: email, propertiesToFetch: propertiesToFetch).map{ $0.flatMap{ AnyDirectoryUser($0) } }
	}
	
	func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, eventLoop: EventLoop) -> Future<AnyDirectoryUser?> {
		do {
			guard let anyService = service as? AnyDirectoryService else {
				return originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch).map{ $0.flatMap{ AnyDirectoryUser($0) } }
			}
			
			let anyUser = user as! AnyDirectoryUser
			if let (service, user): (GitHubService, GitHubService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
				return originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch).map{ $0.flatMap{ AnyDirectoryUser($0) } }
			}
			if let (service, user): (GoogleService, GoogleService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
				return originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch).map{ $0.flatMap{ AnyDirectoryUser($0) } }
			}
			if let (service, user): (LDAPService, LDAPService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
				return originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch).map{ $0.flatMap{ AnyDirectoryUser($0) } }
			}
			if let (service, user): (OpenDirectoryService, OpenDirectoryService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
				return originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch).map{ $0.flatMap{ AnyDirectoryUser($0) } }
			}
			
			throw InvalidArgumentError(message: "Unknown AnyDirectory for getting existing user in type erased directory service.")
		} catch {
			return eventLoop.newFailedFuture(error: error)
		}
	}
	
	func listAllUsers() -> Future<[AnyDirectoryUser]> {
		return originalDirectory.listAllUsers().map{ $0.map{ AnyDirectoryUser($0) } }
	}
	
	var supportsUserCreation: Bool {return originalDirectory.supportsUserCreation}
	func createUser(_ user: AnyDirectoryUser, eventLoop: EventLoop) -> Future<AnyDirectoryUser> {
		guard let u: Base.UserType = user.unwrapped() else {
			return eventLoop.newFailedFuture(error: InvalidArgumentError(message: "Got invalid user to create of type (\(type(of: user))) for directory service of type \(Base.self)"))
		}
		return originalDirectory.createUser(u).map{ AnyDirectoryUser($0) }
	}
	
	var supportsUserUpdate: Bool {return originalDirectory.supportsUserUpdate}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, eventLoop: EventLoop) -> Future<AnyDirectoryUser> {
		guard let u: Base.UserType = user.unwrapped() else {
			return eventLoop.newFailedFuture(error: InvalidArgumentError(message: "Got invalid user to update of type (\(type(of: user))) for directory service of type \(Base.self)"))
		}
		return originalDirectory.updateUser(u, propertiesToUpdate: propertiesToUpdate).map{ AnyDirectoryUser($0) }
	}
	
	var supportsUserDeletion: Bool {return originalDirectory.supportsUserDeletion}
	func deleteUser(_ user: AnyDirectoryUser, eventLoop: EventLoop) -> Future<Void> {
		guard let u: Base.UserType = user.unwrapped() else {
			return eventLoop.newFailedFuture(error: InvalidArgumentError(message: "Got invalid user to delete of type (\(type(of: user))) for directory service of type \(Base.self)"))
		}
		return originalDirectory.deleteUser(u)
	}
	
	var supportsPasswordChange: Bool {return originalDirectory.supportsPasswordChange}
	func changePasswordAction(for user: AnyDirectoryUser) throws -> ResetPasswordAction {
		guard let u: Base.UserType = user.unwrapped() else {
			throw InvalidArgumentError(message: "Got invalid user type (\(type(of: user))) to retrieve password action for directory service of type \(Base.self)")
		}
		return try originalDirectory.changePasswordAction(for: u)
	}
	
	private func serviceUserPair<DestinationServiceType : DirectoryService>(from service: AnyDirectoryService, user: AnyDirectoryService.UserType) throws -> (DestinationServiceType, DestinationServiceType.UserType)? {
		if let service: DestinationServiceType = service.unwrapped() {
			guard let user: DestinationServiceType.UserType = user.unwrapped() else {
				throw InvalidArgumentError(message: "Got a GitHub service to get original user from other user, but other user is not a GitHub user.")
			}
			return (service, user)
		}
		return nil
	}
	
}

public struct AnyDirectoryService : DirectoryService {
	
	public static var providerId: String {
		assertionFailure("Please do not use providerId on AnyDirectoryService. This is an erasure for a concrete DirectoryService type.")
		return "__OfficeKitInternal_OfficeKitServiceConfig_Erasure__"
	}
	
	public typealias ConfigType = AnyOfficeKitServiceConfig
	public typealias UserType = AnyDirectoryUser
	
	public let asyncConfig: AsyncConfig
	
	init<T : DirectoryService>(_ object: T, asyncConfig a: AsyncConfig) {
		box = ConcreteDirectoryBox(originalDirectory: object)
		asyncConfig = a
	}
	
	public func unwrapped<DirectoryType : DirectoryService>() -> DirectoryType? {
		return (box as? ConcreteDirectoryBox<DirectoryType>)?.originalDirectory ?? (box as? ConcreteDirectoryBox<AnyDirectoryService>)?.originalDirectory.unwrapped()
	}
	
	public var config: AnyOfficeKitServiceConfig {
		return box.config
	}
	
	public func logicalUser(from email: Email) throws -> AnyDirectoryUser? {
		return try box.logicalUser(from: email)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> AnyDirectoryUser? {
		return try box.logicalUser(from: user, in: service, eventLoop: asyncConfig.eventLoop)
	}
	
	public func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<AnyDirectoryUser?> {
		return box.existingUser(from: email, propertiesToFetch: propertiesToFetch)
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<AnyDirectoryUser?> {
		return box.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch, eventLoop: asyncConfig.eventLoop)
	}
	
	public func listAllUsers() -> Future<[AnyDirectoryUser]> {
		return box.listAllUsers()
	}
	
	public var supportsUserCreation: Bool {return box.supportsUserCreation}
	public func createUser(_ user: AnyDirectoryUser) -> Future<AnyDirectoryUser> {
		return box.createUser(user, eventLoop: asyncConfig.eventLoop)
	}
	
	public var supportsUserUpdate: Bool {return box.supportsUserUpdate}
	public func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>) -> Future<AnyDirectoryUser> {
		return box.updateUser(user, propertiesToUpdate: propertiesToUpdate, eventLoop: asyncConfig.eventLoop)
	}
	
	public var supportsUserDeletion: Bool {return box.supportsUserDeletion}
	public func deleteUser(_ user: AnyDirectoryUser) -> Future<Void> {
		return box.deleteUser(user, eventLoop: asyncConfig.eventLoop)
	}
	
	public var supportsPasswordChange: Bool {return box.supportsPasswordChange}
	public func changePasswordAction(for user: AnyDirectoryUser) throws -> ResetPasswordAction {
		return try box.changePasswordAction(for: user)
	}
	
	private let box: DirectoryServiceBox
	
}
