/*
 * SynologyService.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation

import CollectionConcurrencyKit
import Crypto
import Email
import GenericJSON
import Logging
import OfficeModelCore
import TaskQueue
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit



public final class SynologyService : UserService {
	
	public static let providerID: String = "happn/synology"
	
	public typealias UserType = SynologyUser
	
	public let id: Tag
	public let name: String
	public let config: SynologyServiceConfig
	
	public let connector: SynologyConnector
	
	/* It seems the Synology does not like when two requests are done concurrently, so we queue the requests and do them one by one. */
	internal let queue = Queue()
	
	public convenience init(id: Tag, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try SynologyServiceConfig(json: jsonConfig)
		try self.init(id: id, name: name, synologyServiceConfig: config, workdir: workdir)
	}
	
	public init(id: Tag, name: String, synologyServiceConfig: SynologyServiceConfig, workdir: URL?) throws {
		self.id = id
		self.name = name
		self.config = synologyServiceConfig
		
		self.connector = try SynologyConnector(
			dsmURL: config.connectorSettings.dsmURL,
			username: config.connectorSettings.username,
			password: config.connectorSettings.password
		)
	}
	
	public func shortDescription(fromUser user: SynologyUser) -> String {
		return user.name
	}
	
	public func string(fromUserID userID: String) -> String {
		return userID
	}
	
	public func userID(fromString string: String) throws -> String {
		return string
	}
	
	public func string(fromPersistentUserID pID: Int) -> String {
		return String(pID)
	}
	
	public func persistentUserID(fromString string: String) throws -> Int {
		return try Int(string) ?! Err.invalidPersistentID
	}
	
	public func alternateIDs(fromUserID userID: String) -> (regular: String, other: Set<String>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> String {
		if let user = user as? UserType {
			return user.oU_id
		}
		
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromPersistentID pID: Int, propertiesToFetch: Set<UserProperty>?) async throws -> SynologyUser? {
		return try await queue.executeOnTaskQueue{
			/* AFAIK to retrieve a user with a given UID, the only way is to get them all and filter. */
			let users = try await self._listAllUsers(includeSuspended: true, propertiesToFetch: propertiesToFetch?.union([.persistentID]))
				.filter{ $0.oU_persistentID == pID }
			guard let user = users.first else {
				return nil
			}
			guard users.count <= 1 else {
				throw OfficeKitError.tooManyUsersFromAPI(users: users)
			}
			return user
		}
	}
	
	public func existingUser(fromID uID: String, propertiesToFetch: Set<UserProperty>?) async throws -> SynologyUser? {
		return try await queue.executeOnTaskQueue{
			try await self._existingUser(fromID: uID, propertiesToFetch: propertiesToFetch)
		}
	}
	
	func _existingUser(fromID uID: String, propertiesToFetch: Set<UserProperty>?) async throws -> SynologyUser? {
		try await connector.connectIfNeeded()
		
		/* We remove the uid and name from the fields as it is invalid to ask for them.
		 * Interestingly, they are returned anyway… */
		let fields = SynologyUser.keysFromProperties(propertiesToFetch).subtracting([.uid, .name])
		let users = try await URLRequestDataOperation<ApiResponse<UserGetResponseBody>>.forAPIRequest(
			urlRequest: try connector.urlRequestForEntryCGI(GETRequest: UserGetRequestBody(userNameToFetch: uID, additionalFields: fields)),
			requestProcessors: [AuthRequestProcessor(connector)],
			retryProviders: []
		).startAndGetResult().result.get().users
		guard let user = users.first else {
			return nil
		}
		guard users.count <= 1 else {
			throw OfficeKitError.tooManyUsersFromAPI(users: users)
		}
		return user
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?) async throws -> [SynologyUser] {
		return try await queue.executeOnTaskQueue{
			return try await self._listAllUsers(includeSuspended: includeSuspended, propertiesToFetch: propertiesToFetch)
		}
	}
	
	func _listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?) async throws -> [SynologyUser] {
		try await connector.connectIfNeeded()
		let fields = SynologyUser.keysFromProperties(propertiesToFetch)
		return try await URLRequestDataOperation<ApiResponse<UsersListResponseBody>>.forAPIRequest(
			urlRequest: try connector.urlRequestForEntryCGI(GETRequest: UsersListRequestBody(additionalFields: fields)),
			requestProcessors: [AuthRequestProcessor(connector)],
			retryProviders: []
		).startAndGetResult().result.get().users
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: SynologyUser) async throws -> SynologyUser {
		return try await queue.executeOnTaskQueue{
			if user.uid != nil {
				/* Note: I did not test whether the Synology would ignore the value if I sent it. */
				Conf.logger?.warning("The uid property of a Synology user is ignored when creating it.")
			}
			try await self.connector.connectIfNeeded()
			return try await URLRequestDataOperation<ApiResponse<SynologyUser>>.forAPIRequest(
				urlRequest: try self.connector.urlRequestForEntryCGI(GETRequest: UserCreateRequestBody(user: user)),
				requestProcessors: [AuthRequestProcessor(self.connector)],
				retryProviders: []
			).startAndGetResult().result.get()
		}
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: SynologyUser, propertiesToUpdate: Set<UserProperty>) async throws -> SynologyUser {
		return try await queue.executeOnTaskQueue{
			try await self.connector.connectIfNeeded()
			let keys = SynologyUser.keysFromProperties(propertiesToUpdate)
			let newUser = try await URLRequestDataOperation<ApiResponse<SynologyUser>>.forAPIRequest(
				urlRequest: try self.connector.urlRequestForEntryCGI(GETRequest: UserUpdateRequestBody(user: user.forPatching(properties: keys))),
				requestProcessors: [AuthRequestProcessor(self.connector)],
				retryProviders: []
			).startAndGetResult().result.get()
			/* We have to re-retrieve the user as there’s no way to tell the Synology we want our updated fields returned AFAICT.
			 * We retrieve the user from the non-persistent ID as it’s more efficient. */
			return try await self._existingUser(fromID: newUser.oU_id, propertiesToFetch: propertiesToUpdate) ?? newUser
		}
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: SynologyUser) async throws {
		return try await queue.executeOnTaskQueue{
			try await self.connector.connectIfNeeded()
			let res = try await URLRequestDataOperation<ApiResponse<UsersDeletionResponseBody>>.forAPIRequest(
				urlRequest: try self.connector.urlRequestForEntryCGI(GETRequest: UsersDeletionRequestBody(users: [user])),
				requestProcessors: [AuthRequestProcessor(self.connector)],
				retryProviders: []
			).startAndGetResult().result.get()
			guard res.errors.onlyElement == 3102 else {
				throw Err.unexpectedApiResponse
			}
		}
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: SynologyUser, to newPassword: String) async throws {
		var user = user
		let passwordProperty = UserProperty(rawValue: SynologyService.providerID + "/password")
		guard user.oU_setValue(newPassword, forProperty: passwordProperty, convertMismatchingTypes: false).isSuccessful else {
			throw Err.internalError
		}
		_ = try await updateUser(user, propertiesToUpdate: [passwordProperty])
	}
	
}
