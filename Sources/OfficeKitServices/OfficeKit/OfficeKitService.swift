/*
 * OfficeKitService.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import Email
import GenericJSON
import OfficeModelCore
import OperationAwaiting
import ServiceKit
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit



public final class OfficeKitService : UserService {
	
	public static let providerID: String = "happn/officekit"
	
	public typealias UserType = OfficeKitUser
	
	public let id: String
	public let name: String
	public let config: OfficeKitServiceConfig
	
	public convenience init(id: String, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try OfficeKitServiceConfig(json: jsonConfig)
		self.init(id: id, name: name, officeKitServiceConfig: config)
	}
	
	public init(id: String, name: String, officeKitServiceConfig: OfficeKitServiceConfig) {
		self.id = id
		self.name = name
		self.config = officeKitServiceConfig
		self.authenticator = OfficeKitAuthenticator(secret: config.secret)
	}
	
	public func shortDescription(fromUser user: OfficeKitUser) -> String {
		return "OfficeKitUser<\(user.id)>"
	}
	
	public func string(fromUserID userID: TaggedID) -> String {
		return userID.stringValue
	}
	
	public func userID(fromString string: String) throws -> TaggedID {
		return try .init(string) ?! Err.invalidUserIDFormat
	}
	
	public func string(fromPersistentUserID pID: TaggedID) -> String {
		return pID.stringValue
	}
	
	public func persistentUserID(fromString string: String) throws -> TaggedID {
		return try .init(string) ?! Err.invalidUserIDFormat
	}
	
	public func alternateIDs(fromUserID userID: TaggedID) -> (regular: TaggedID, other: Set<TaggedID>) {
#warning("TODO: Use config.alternateUserIDsBuilders")
		return (userID, [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> TaggedID {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap(TaggedID.init(_:))
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromID uID: TaggedID, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> OfficeKitUser? {
		/* We use POST because 1. we want the request _not_ to be idempotent and 2. we want to avoid sending user ID or other sensitive informations in the logs.
		 * Not sure this is justified; we can change this if needed. */
		let request = ExistingUserFromIDRequest(userID: uID, propertiesToFetch: propertiesToFetch)
		let operation = try URLRequestDataOperation<WrappedOptional<OfficeKitUser>>.forAPIRequest(
			url: config.upstreamURL.appending("existing-user-from-id"), method: "POST", httpBody: request,
			requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await operation.startAndGetResult().result.value
	}
	
	public func existingUser(fromPersistentID pID: TaggedID, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> OfficeKitUser? {
		let request = ExistingUserFromPersistentIDRequest(userPersistentID: pID, propertiesToFetch: propertiesToFetch)
		let operation = try URLRequestDataOperation<WrappedOptional<OfficeKitUser>>.forAPIRequest(
			url: config.upstreamURL.appending("existing-user-from-persistent-id"), method: "POST", httpBody: request,
			requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await operation.startAndGetResult().result.value
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [OfficeKitUser] {
		let request = ListAllUsersRequest(includeSuspended: includeSuspended, propertiesToFetch: propertiesToFetch)
		let operation = try URLRequestDataOperation<[OfficeKitUser]>.forAPIRequest(
			url: config.upstreamURL.appending("list-all-users").appendingQueryParameters(from: request),
			requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await operation.startAndGetResult().result
	}
	
	public var supportsUserCreation: Bool {
		return config.supportsUserCreation
	}
	public func createUser(_ user: OfficeKitUser, using services: Services) async throws -> OfficeKitUser {
		let request = CreateUserRequest(user: user)
		let operation = try URLRequestDataOperation<OfficeKitUser>.forAPIRequest(
			url: config.upstreamURL.appending("create-user"), method: "POST", httpBody: request,
			requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await operation.startAndGetResult().result
	}
	
	public var supportsUserUpdate: Bool {
		return config.supportsUserUpdate
	}
	public func updateUser(_ user: OfficeKitUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> OfficeKitUser {
		let request = UpdateUserRequest(user: user, propertiesToUpdate: propertiesToUpdate)
		let operation = try URLRequestDataOperation<OfficeKitUser>.forAPIRequest(
			url: config.upstreamURL.appending("update-user"), method: "PATCH", httpBody: request,
			requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		return try await operation.startAndGetResult().result
	}
	
	public var supportsUserDeletion: Bool {
		return config.supportsUserDeletion
	}
	public func deleteUser(_ user: OfficeKitUser, using services: Services) async throws {
		let request = DeleteUserRequest(user: user)
		let operation = try URLRequestDataOperation<Empty>.forAPIRequest(
			url: config.upstreamURL.appending("delete-user"), method: "DELETE", httpBody: request,
			requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		_ = try await operation.startAndGetResult()
	}
	
	public var supportsPasswordChange: Bool {
		return config.supportsPasswordChange
	}
	public func changePassword(of user: OfficeKitUser, to newPassword: String, using services: Services) async throws {
		let request = ChangePasswordRequest(user: user, newPassword: newPassword)
		let operation = try URLRequestDataOperation<Empty>.forAPIRequest(
			url: config.upstreamURL.appending("change-password"), method: "POST", httpBody: request,
			requestProcessors: [AuthRequestProcessor(authenticator)], retryProviders: []
		)
		_ = try await operation.startAndGetResult()
	}
	
	private let authenticator: OfficeKitAuthenticator
	
}
