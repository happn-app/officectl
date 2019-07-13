/*
 * AnyDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 27/06/2019.
 */

import Foundation

import Async
import GenericJSON
import Service



private protocol DirectoryServiceBox {
	
	var config: AnyOfficeKitServiceConfig {get}
	
	func string(fromUserId userId: AnyHashable) -> String
	func userId(fromString string: String) throws -> AnyHashable
	
	func shortDescription(from user: AnyDirectoryUser) -> String
	func exportableJSON(from user: AnyDirectoryUser) throws -> JSON
	
	func logicalUser(fromPersistentId pId: AnyHashable, hints: [DirectoryUserProperty : Any]) throws -> AnyDirectoryUser
	func logicalUser(fromUserId uId: AnyHashable, hints: [DirectoryUserProperty : Any]) throws -> AnyDirectoryUser
	func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any]) throws -> AnyDirectoryUser
	func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any]) throws -> AnyDirectoryUser
	
	func existingUser(fromPersistentId pId: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?>
	func existingUser(fromUserId uId: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?>
	func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?>
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
	
	func string(fromUserId userId: AnyHashable) -> String {
		guard let typedId = userId as? Base.UserType.UserIdType else {
			#warning("TODO: Log the error")
			/* The source user type is unknown, so we return a purposefully invalid
			 * id. This is not ideal… */
			return ""
		}
		return originalDirectory.string(fromUserId: typedId)
	}
	
	func userId(fromString string: String) throws -> AnyHashable {
		return try AnyHashable(originalDirectory.userId(fromString: string))
	}
	
	func shortDescription(from user: AnyDirectoryUser) -> String {
		guard let u: Base.UserType = user.unboxed() else {
			return "UnknownAnyDirectoryUser<\(user)>"
		}
		return originalDirectory.shortDescription(from: u)
	}
	
	func exportableJSON(from user: AnyDirectoryUser) throws -> JSON {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user (\(user)) from which to create an exportable JSON.")
		}
		return try originalDirectory.exportableJSON(from: u)
	}
	
	func logicalUser(fromPersistentId pId: AnyHashable, hints: [DirectoryUserProperty : Any]) throws -> AnyDirectoryUser {
		guard let typedId = pId as? Base.UserType.PersistentIdType else {
			throw InvalidArgumentError(message: "Got invalid persistent user id (\(pId)) for creating logical user with directory service of type \(Base.self)")
		}
		return try originalDirectory.logicalUser(fromPersistentId: typedId, hints: hints).erased()
	}
	
	func logicalUser(fromUserId uId: AnyHashable, hints: [DirectoryUserProperty : Any]) throws -> AnyDirectoryUser {
		guard let typedId = uId as? Base.UserType.UserIdType else {
			throw InvalidArgumentError(message: "Got invalid user id (\(uId)) for creating logical user with directory service of type \(Base.self)")
		}
		return try originalDirectory.logicalUser(fromUserId: typedId, hints: hints).erased()
	}
	
	func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any]) throws -> AnyDirectoryUser {
		return try originalDirectory.logicalUser(fromEmail: email, hints: hints).erased()
	}
	
	func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any]) throws -> AnyDirectoryUser {
		return try originalDirectory.logicalUser(fromUser: user, in: service, hints: hints).erased()
	}
	
	func existingUser(fromPersistentId pId: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		guard let typedId = pId as? Base.UserType.PersistentIdType else {
			throw InvalidArgumentError(message: "Got invalid persistent user id (\(pId)) for fetching user with directory service of type \(Base.self)")
		}
		return try originalDirectory.existingUser(fromPersistentId: typedId, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
	}
	
	func existingUser(fromUserId uId: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		guard let typedId = uId as? Base.UserType.UserIdType else {
			throw InvalidArgumentError(message: "Got invalid user id (\(uId)) for fetching user with directory service of type \(Base.self)")
		}
		return try originalDirectory.existingUser(fromUserId: typedId, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
	}
	
	func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try originalDirectory.existingUser(fromEmail: email, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
	}
	
	func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try originalDirectory.existingUser(from: user, in: service, propertiesToFetch: propertiesToFetch, on: container).map{ $0?.erased() }
	}
	
	func listAllUsers(on container: Container) throws -> Future<[AnyDirectoryUser]> {
		return try originalDirectory.listAllUsers(on : container).map{ $0.map{ $0.erased() } }
	}
	
	var supportsUserCreation: Bool {return originalDirectory.supportsUserCreation}
	func createUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<AnyDirectoryUser> {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user to create (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.createUser(u, on: container).map{ $0.erased() }
	}
	
	var supportsUserUpdate: Bool {return originalDirectory.supportsUserUpdate}
	func updateUser(_ user: AnyDirectoryUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser> {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user to update (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.updateUser(u, propertiesToUpdate: propertiesToUpdate, on: container).map{ $0.erased() }
	}
	
	var supportsUserDeletion: Bool {return originalDirectory.supportsUserDeletion}
	func deleteUser(_ user: AnyDirectoryUser, on container: Container) throws -> Future<Void> {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user to delete (\(user)) for directory service of type \(Base.self)")
		}
		return try originalDirectory.deleteUser(u, on: container)
	}
	
	var supportsPasswordChange: Bool {return originalDirectory.supportsPasswordChange}
	func changePasswordAction(for user: AnyDirectoryUser, on container: Container) throws -> ResetPasswordAction {
		guard let u: Base.UserType = user.unboxed() else {
			throw InvalidArgumentError(message: "Got invalid user (\(user)) to retrieve password action for directory service of type \(Base.self)")
		}
		return try originalDirectory.changePasswordAction(for: u, on: container)
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
	
	public var config: AnyOfficeKitServiceConfig {
		return box.config
	}
	
	public func string(fromUserId userId: AnyHashable) -> String {
		return box.string(fromUserId: userId)
	}
	
	public func userId(fromString string: String) throws -> AnyHashable {
		return try box.userId(fromString: string)
	}
	
	public func shortDescription(from user: AnyDirectoryUser) -> String {
		return box.shortDescription(from: user)
	}
	
	public func exportableJSON(from user: AnyDirectoryUser) throws -> JSON {
		return try box.exportableJSON(from: user)
	}
	
	public func logicalUser(fromPersistentId pId: AnyHashable, hints: [DirectoryUserProperty : Any]) throws -> AnyDirectoryUser {
		return try box.logicalUser(fromPersistentId: pId, hints: hints)
	}
	
	public func logicalUser(fromUserId uId: AnyHashable, hints: [DirectoryUserProperty : Any]) throws -> AnyDirectoryUser {
		return try box.logicalUser(fromUserId: uId, hints: hints)
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any]) throws -> AnyDirectoryUser {
		return try box.logicalUser(fromEmail: email, hints: hints)
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any]) throws -> AnyDirectoryUser {
		return try box.logicalUser(fromUser: user, in: service, hints: hints)
	}
	
	public func existingUser(fromPersistentId pId: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try box.existingUser(fromPersistentId: pId, propertiesToFetch: propertiesToFetch, on: container)
	}
	
	public func existingUser(fromUserId uId: AnyHashable, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try box.existingUser(fromUserId: uId, propertiesToFetch: propertiesToFetch, on: container)
	}
	
	public func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<AnyDirectoryUser?> {
		return try box.existingUser(fromEmail: email, propertiesToFetch: propertiesToFetch, on: container)
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
	
	fileprivate let box: DirectoryServiceBox
	
}

extension DirectoryService {
	
	public func erased() -> AnyDirectoryService {
		if let erased = self as? AnyDirectoryService {
			return erased
		}
		
		return AnyDirectoryService(self)
	}
	
	public func unboxed<DirectoryType : DirectoryService>() -> DirectoryType? {
		guard let anyService = self as? AnyDirectoryService else {
			/* Nothing to unbox, just return self */
			return self as? DirectoryType
		}
		
		return (anyService.box as? ConcreteDirectoryBox<DirectoryType>)?.originalDirectory ?? (anyService.box as? ConcreteDirectoryBox<AnyDirectoryService>)?.originalDirectory.unboxed()
	}
	
}
