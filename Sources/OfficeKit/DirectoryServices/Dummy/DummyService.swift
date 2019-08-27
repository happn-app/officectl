/*
 * DummyOpenDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 21/07/2019.
 */

import Foundation

import GenericJSON
import GenericStorage
import Service



public struct DummyServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		throw InternalError(message: "The DummyServiceConfig cannot be instantiated")
	}
	
	private init() {
		fatalError()
	}
	
}

public struct DummyServiceUser : DirectoryUser {
	
	public typealias UserIdType = Never
	public typealias PersistentIdType = Never
	
	public var userId: Never
	public var persistentId: RemoteProperty<Never>
	public var emails: RemoteProperty<[Email]>
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	public var nickname: RemoteProperty<String?>
	
	private init() {
		fatalError()
	}
	
}

public final class DummyService : DirectoryService {
	
	public static let providerId = "dummy"
	
	public typealias ConfigType = DummyServiceConfig
	public typealias UserIdType = DummyServiceUser
	
	public let config: DummyServiceConfig
	
	public init(config c: DummyServiceConfig) {
		config = c
	}
	
	public func shortDescription(from user: DummyServiceUser) -> String {
		return "<ERROR>"
	}
	
	public func string(fromUserId userId: Never) -> String {
		/* Remove when we have Swift 5.1 compiler in Linux… */
		#if swift(<5.1)
		fatalError()
		#endif
	}
	
	public func userId(fromString string: String) throws -> Never {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func string(fromPersistentId pId: Never) -> String {
		/* Remove when we have Swift 5.1 compiler in Linux… */
		#if swift(<5.1)
		fatalError()
		#endif
	}
	
	public func persistentId(fromString string: String) throws -> Never {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func json(fromUser user: DummyServiceUser) throws -> JSON {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> DummyServiceUser {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func existingUser(fromPersistentId pId: Never, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<DummyServiceUser?> {
		/* Remove when we have Swift 5.1 compiler in Linux… */
		#if swift(<5.1)
		fatalError()
		#endif
	}
	
	public func existingUser(fromUserId dn: Never, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<DummyServiceUser?> {
		/* Remove when we have Swift 5.1 compiler in Linux… */
		#if swift(<5.1)
		fatalError()
		#endif
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[DummyServiceUser]> {
		throw NotAvailableOnThisPlatformError()
	}
	
	public let supportsUserCreation = false
	public func createUser(_ user: DummyServiceUser, on container: Container) throws -> Future<DummyServiceUser> {
		throw NotAvailableOnThisPlatformError()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: DummyServiceUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<DummyServiceUser> {
		throw NotAvailableOnThisPlatformError()
	}
	
	public let supportsUserDeletion = false
	public func deleteUser(_ user: DummyServiceUser, on container: Container) throws -> Future<Void> {
		throw NotAvailableOnThisPlatformError()
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: DummyServiceUser, on container: Container) throws -> ResetPasswordAction {
		throw NotAvailableOnThisPlatformError()
	}
	
}
