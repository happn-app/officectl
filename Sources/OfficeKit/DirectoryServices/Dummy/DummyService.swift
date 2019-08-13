/*
 * DummyOpenDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 21/07/2019.
 */

import Foundation

import GenericStorage
import Service



public struct DummyServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	
	public var serviceId: String
	public var serviceName: String
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		throw InternalError(message: "The DummyServiceConfig cannot be instantiated")
	}
	
	private init() {
		providerId = ""
		serviceId = ""
		serviceName = ""
	}
	
}

public struct DummyServiceUser : DirectoryUser {
	
	public typealias UserIdType = Int
	public typealias PersistentIdType = Int
	
	public var userId: Int
	public var persistentId: RemoteProperty<Int>
	public var emails: RemoteProperty<[Email]>
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	public var nickname: RemoteProperty<String?>
	
	private init() {
		userId = 0
		persistentId = .unsupported
		emails = .unsupported
		firstName = .unsupported
		lastName = .unsupported
		nickname = .unsupported
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
	
	public func string(fromUserId userId: Int) -> String {
		/* Purposefully invalid id */
		return ""
	}
	
	public func userId(fromString string: String) throws -> Int {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func genericUser(fromUser user: DummyServiceUser) throws -> GenericDirectoryUser {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func logicalUser(fromGenericUser genericUser: GenericDirectoryUser) throws -> DummyServiceUser {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func existingUser(fromPersistentId pId: Int, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<DummyServiceUser?> {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func existingUser(fromUserId dn: Int, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<DummyServiceUser?> {
		throw NotAvailableOnThisPlatformError()
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
