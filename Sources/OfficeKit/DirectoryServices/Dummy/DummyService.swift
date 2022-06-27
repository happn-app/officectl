/*
 * DummyOpenDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/21.
 */

import Foundation

import Email
import GenericJSON
import NIO

import GenericStorage
import OfficeModel
import ServiceKit



//public struct DummyServiceConfig : OfficeKitServiceConfig {
//
//	public var providerID: String
//	public let isHelperService = true
//
//	public var serviceID: String
//	public var serviceName: String
//
//	public var mergePriority: Int?
//
//	public init(providerID pID: String, serviceID id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
//		throw InternalError(message: "The DummyServiceConfig cannot be instantiated")
//	}
//
//	private init() {
//		fatalError()
//	}
//
//}
//
//public struct DummyServiceUser : DirectoryUser {
//
//	public typealias IDType = Never
//	public typealias PersistentIDType = Never
//
//	public var userID: Never
//	public var remotePersistentID: RemoteProperty<Never>
//	public var remoteIdentifyingEmail: RemoteProperty<Email?>
//	public var remoteOtherEmails: RemoteProperty<[Email]>
//	public var remoteFirstName: RemoteProperty<String?>
//	public var remoteLastName: RemoteProperty<String?>
//	public var remoteNickname: RemoteProperty<String?>
//
//	private init() {
//		fatalError()
//	}
//
//}
//
//public final class DummyService : UserDirectoryService {
//
//	public static let providerID = "dummy"
//
//	public typealias ConfigType = DummyServiceConfig
//	public typealias UserIDType = DummyServiceUser
//
//	public let config: DummyServiceConfig
//	public let globalConfig: GlobalConfig
//
//	public init(config c: DummyServiceConfig, globalConfig gc: GlobalConfig) {
//		config = c
//		globalConfig = gc
//	}
//
//	public func shortDescription(fromUser user: DummyServiceUser) -> String {
//		return "<ERROR>"
//	}
//
//	public func string(fromUserID userID: Never) -> String {
//	}
//
//	public func userID(fromString string: String) throws -> Never {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//	public func string(fromPersistentUserID pID: Never) -> String {
//	}
//
//	public func persistentUserID(fromString string: String) throws -> Never {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//	public func json(fromUser user: DummyServiceUser) throws -> JSON {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> DummyServiceUser {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout DummyServiceUser, allowUserIDChange: Bool) -> Set<DirectoryUserProperty> {
//		return []
//	}
//
//	public func existingUser(fromPersistentID pID: Never, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> DummyServiceUser? {
//	}
//
//	public func existingUser(fromUserID dn: Never, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> DummyServiceUser? {
//	}
//
//	public func listAllUsers(using services: Services) async throws -> [DummyServiceUser] {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//	public let supportsUserCreation = false
//	public func createUser(_ user: DummyServiceUser, using services: Services) async throws -> DummyServiceUser {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//	public let supportsUserUpdate = false
//	public func updateUser(_ user: DummyServiceUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> DummyServiceUser {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//	public let supportsUserDeletion = false
//	public func deleteUser(_ user: DummyServiceUser, using services: Services) async throws {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//	public let supportsPasswordChange = false
//	public func changePasswordAction(for user: DummyServiceUser, using services: Services) throws -> ResetPasswordAction {
//		throw NotAvailableOnThisPlatformError()
//	}
//
//}
