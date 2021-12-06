/*
 * DummyOpenDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 21/07/2019.
 */

import Foundation

import GenericJSON
import GenericStorage
import NIO
import ServiceKit



public struct DummyServiceConfig : OfficeKitServiceConfig {
	
	public var providerId: String
	public let isHelperService = true
	
	public var serviceId: String
	public var serviceName: String
	
	public var mergePriority: Int?
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		throw InternalError(message: "The DummyServiceConfig cannot be instantiated")
	}
	
	private init() {
		fatalError()
	}
	
}

public struct DummyServiceUser : DirectoryUser {
	
	public typealias IdType = Never
	public typealias PersistentIdType = Never
	
	public var userId: Never
	public var persistentId: RemoteProperty<Never>
	public var identifyingEmail: RemoteProperty<Email?>
	public var otherEmails: RemoteProperty<[Email]>
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	public var nickname: RemoteProperty<String?>
	
	private init() {
		fatalError()
	}
	
}

public final class DummyService : UserDirectoryService {
	
	public static let providerId = "dummy"
	
	public typealias ConfigType = DummyServiceConfig
	public typealias UserIdType = DummyServiceUser
	
	public let config: DummyServiceConfig
	public let globalConfig: GlobalConfig
	
	public init(config c: DummyServiceConfig, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(fromUser user: DummyServiceUser) -> String {
		return "<ERROR>"
	}
	
	public func string(fromUserId userId: Never) -> String {
	}
	
	public func userId(fromString string: String) throws -> Never {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func string(fromPersistentUserId pId: Never) -> String {
	}
	
	public func persistentUserId(fromString string: String) throws -> Never {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func json(fromUser user: DummyServiceUser) throws -> JSON {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> DummyServiceUser {
		throw NotAvailableOnThisPlatformError()
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout DummyServiceUser, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		return []
	}
	
	public func existingUser(fromPersistentId pId: Never, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> DummyServiceUser? {
	}
	
	public func existingUser(fromUserId dn: Never, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> DummyServiceUser? {
	}
	
	public func listAllUsers(using services: Services) async throws -> [DummyServiceUser] {
		throw NotAvailableOnThisPlatformError()
	}
	
	public let supportsUserCreation = false
	public func createUser(_ user: DummyServiceUser, using services: Services) async throws -> DummyServiceUser {
		throw NotAvailableOnThisPlatformError()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: DummyServiceUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> DummyServiceUser {
		throw NotAvailableOnThisPlatformError()
	}
	
	public let supportsUserDeletion = false
	public func deleteUser(_ user: DummyServiceUser, using services: Services) async throws {
		throw NotAvailableOnThisPlatformError()
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: DummyServiceUser, using services: Services) throws -> ResetPasswordAction {
		throw NotAvailableOnThisPlatformError()
	}
	
}
