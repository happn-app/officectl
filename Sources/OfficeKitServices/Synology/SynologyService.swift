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
		/* AFAIK to retrieve a user with a given UID, the only way is to get them all and filter. */
		let users = try await listAllUsers(includeSuspended: true, propertiesToFetch: propertiesToFetch?.union([.persistentID]))
			.filter{ $0.oU_persistentID == pID }
		guard let user = users.first else {
			return nil
		}
		guard users.count <= 1 else {
			throw OfficeKitError.tooManyUsersFromAPI(users: users)
		}
		return user
	}
	
	public func existingUser(fromID uID: String, propertiesToFetch: Set<UserProperty>?) async throws -> SynologyUser? {
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
		/* Let’s set the uid for the user if it is not already set. */
		var user = user
		if user.uid == nil {
			/* First let’s get all the users.
			 * We get the max of the current UIDs; the goal is to avoid reusing a UID.
			 * If the UID w/ max UID gets deleted, the next user will have the same UID (or lower), but I don’t see how I can mitigate that… */
			let users = try await listAllUsers(includeSuspended: true, propertiesToFetch: [.persistentID])
			let maxUID = users.compactMap(\.uid).max()
			user.uid = maxUID.flatMap{ $0 + 1 } ?? 1024 /* First UID seems to be 1024. */
		} else {
			Conf.logger?.warning("Setting the uid for a Synology user is not recommended. It should be left empty to be inferred from the current users on the directory.")
		}
		
		try await connector.connectIfNeeded()
		return try await URLRequestDataOperation<ApiResponse<SynologyUser>>.forAPIRequest(
			urlRequest: try connector.urlRequestForEntryCGI(GETRequest: UserCreateRequestBody(user: user)),
			requestProcessors: [AuthRequestProcessor(connector)],
			retryProviders: []
		).startAndGetResult().result.get()
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: SynologyUser, propertiesToUpdate: Set<UserProperty>) async throws -> SynologyUser {
		return try await user.update(properties: SynologyUser.keysFromProperties(propertiesToUpdate), connector: connector)
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: SynologyUser) async throws {
		return try await user.delete(connector: connector)
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
