/*
 * AnyDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 27/06/2019.
 */

import Foundation

import Async
import Service



private protocol DirectoryServiceBox {
	
	var config: AnyOfficeKitServiceConfig {get}
	
	func string(from userId: AnyHashable) -> String
	func userId(from string: String) throws -> AnyHashable
	
	func logicalUser(from email: Email) throws -> AnyDirectoryUser?
	func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> AnyDirectoryUser?
	
	func existingUser(from id: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?>
	func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?>
	func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?>
	
	func listAllUsers(on container: Container) throws -> Future<[AnyDirectoryUser]>
	
	var supportsUserCreation: Bool {get}
	func createUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<AnyDirectoryUser>
	
	var supportsUserUpdate: Bool {get}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser>
	
	var supportsUserDeletion: Bool {get}
	func deleteUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<Void>
	
	var supportsPasswordChange: Bool {get}
	func changePasswordAction(for user: AnyDirectoryUser, on container: Container) throws -> ResetPasswordAction
	
}

private struct ConcreteDirectoryBox<Base : DirectoryService> : DirectoryServiceBox {
	
	let originalDirectory: Base
	
	var config: AnyOfficeKitServiceConfig {
		return originalDirectory.config.erased()
	}
	
	func string(from userId: AnyHashable) -> String {
		/* TODO? I’m not a big fan of this forced unwrapping… */
		let typedId = userId as! Base.UserType.IdType
		return originalDirectory.string(from: typedId)
	}
	
	func userId(from string: String) throws -> AnyHashable {
		return try AnyHashable(originalDirectory.userId(from: string))
	}
	
	func logicalUser(from email: Email) throws -> AnyDirectoryUser? {
		return try originalDirectory.logicalUser(from: email)?.erased()
	}
	
	func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> AnyDirectoryUser? {
		guard let anyService = service as? AnyDirectoryService else {
			return try originalDirectory.logicalUser(from: user, in: service)?.erased()
		}
		
		let anyUser = user as! AnyDirectoryUser
		if let (service, user): (GitHubService, GitHubService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try originalDirectory.logicalUser(from: user, in: service)?.erased()
		}
		if let (service, user): (GoogleService, GoogleService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try originalDirectory.logicalUser(from: user, in: service)?.erased()
		}
		if let (service, user): (LDAPService, LDAPService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try originalDirectory.logicalUser(from: user, in: service)?.erased()
		}
		if let (service, user): (OpenDirectoryService, OpenDirectoryService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try originalDirectory.logicalUser(from: user, in: service)?.erased()
		}
		
		throw InvalidArgumentError(message: "Unknown AnyDirectory for getting existing user in type erased directory service.")
	}
	
	func existingUser(from id: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		guard let typedId = id as? Base.UserType.IdType else {
			throw InvalidArgumentError(message: "Got invalid user id (\(id)) for fetching user with directory service of type \(Base.self)")
		}
		return try originalDirectory.existingUser(from: typedId, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
	}
	
	func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try originalDirectory.existingUser(from: email, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
	}
	
	func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		guard let anyService = service as? AnyDirectoryService else {
			return try originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
		}
		
		let anyUser = user as! AnyDirectoryUser
		if let (service, user): (GitHubService, GitHubService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
		}
		if let (service, user): (GoogleService, GoogleService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
		}
		if let (service, user): (LDAPService, LDAPService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
		}
		if let (service, user): (OpenDirectoryService, OpenDirectoryService.UserType) = try serviceUserPair(from: anyService, user: anyUser) {
			return try originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
		}
		
		throw InvalidArgumentError(message: "Unknown AnyDirectory for getting existing user in type erased directory service.")
	}
	
	func listAllUsers(on container: Container) throws -> Future<[AnyDirectoryUser]> {
		return try originalDirectory.listAllUsers(on : container).map{ $0.map{ $0.erased() } }
	}
	
	var supportsUserCreation: Bool {return originalDirectory.supportsUserCreation}
	func createUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<AnyDirectoryUser> {
		guard let u: Base.UserType = user.unwrapped() else {
			throw InvalidArgumentError(message: "Got invalid user to create (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.createUser(u, on: container).map{ $0.erased() }
	}
	
	var supportsUserUpdate: Bool {return originalDirectory.supportsUserUpdate}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser> {
		guard let u: Base.UserType = user.unwrapped() else {
			throw InvalidArgumentError(message: "Got invalid user to update (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.updateUser(u, propertiesToUpdate: propertiesToUpdate, on: container).map{ $0.erased() }
	}
	
	var supportsUserDeletion: Bool {return originalDirectory.supportsUserDeletion}
	func deleteUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<Void> {
		guard let u: Base.UserType = user.unwrapped() else {
			throw InvalidArgumentError(message: "Got invalid user to delete (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.deleteUser(u, on: container)
	}
	
	var supportsPasswordChange: Bool {return originalDirectory.supportsPasswordChange}
	func changePasswordAction(for user: AnyDirectoryUser, on container: Container) throws -> ResetPasswordAction {
		guard let u: Base.UserType = user.unwrapped() else {
			throw InvalidArgumentError(message: "Got invalid user (\(user)) to retrieve password action for directory service of type \(Base.self)")
		}
		return try originalDirectory.changePasswordAction(for: u, on: container)
	}
	
	private func serviceUserPair<DestinationServiceType : DirectoryService>(from service: AnyDirectoryService, user: AnyDirectoryService.UserType) throws -> (DestinationServiceType, DestinationServiceType.UserType)? {
		if let service: DestinationServiceType = service.unboxed() {
			guard let user: DestinationServiceType.UserType = user.unwrapped() else {
				throw InvalidArgumentError(message: "Got an incompatible servicer/user pair.")
			}
			return (service, user)
		}
		return nil
	}
	
}

public class AnyDirectoryService : DirectoryService {
	
	public static var providerId: String {
		assertionFailure("Please do not use providerId on AnyDirectoryService. This is an erasure for a concrete DirectoryService type.")
		return "__OfficeKitInternal_OfficeKitServiceConfig_Erasure__"
	}
	
	public typealias ConfigType = AnyOfficeKitServiceConfig
	public typealias UserType = AnyDirectoryUser
	
	init<T : DirectoryService>(_ object: T) {
		box = ConcreteDirectoryBox(originalDirectory: object)
	}
	
	public func unboxed<DirectoryType : DirectoryService>() -> DirectoryType? {
		return (box as? ConcreteDirectoryBox<DirectoryType>)?.originalDirectory ?? (box as? ConcreteDirectoryBox<AnyDirectoryService>)?.originalDirectory.unboxed()
	}
	
	public var config: AnyOfficeKitServiceConfig {
		return box.config
	}
	
	public func string(from userId: AnyHashable) -> String {
		return box.string(from: userId)
	}
	
	public func userId(from string: String) throws -> AnyHashable {
		return try box.userId(from: string)
	}
	
	public func logicalUser(from email: Email) throws -> AnyDirectoryUser? {
		return try box.logicalUser(from: email)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> AnyDirectoryUser? {
		return try box.logicalUser(from: user, in: service)
	}
	
	public func existingUser(from id: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try box.existingUser(from: id, propertiesToFetch: propertiesToFetch, on: container)
	}
	
	public func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try box.existingUser(from: email, propertiesToFetch: propertiesToFetch, on: container)
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try box.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch, on: container)
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[AnyDirectoryUser]> {
		return try box.listAllUsers(on: container)
	}
	
	public var supportsUserCreation: Bool {return box.supportsUserCreation}
	public func createUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<AnyDirectoryUser> {
		return try box.createUser(user, on: container)
	}
	
	public var supportsUserUpdate: Bool {return box.supportsUserUpdate}
	public func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser> {
		return try box.updateUser(user, propertiesToUpdate: propertiesToUpdate, on: container)
	}
	
	public var supportsUserDeletion: Bool {return box.supportsUserDeletion}
	public func deleteUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<Void> {
		return try box.deleteUser(user, on: container)
	}
	
	public var supportsPasswordChange: Bool {return box.supportsPasswordChange}
	public func changePasswordAction(for user: AnyDirectoryUser, on container: Container) throws -> ResetPasswordAction {
		return try box.changePasswordAction(for: user, on: container)
	}
	
	private let box: DirectoryServiceBox
	
}
