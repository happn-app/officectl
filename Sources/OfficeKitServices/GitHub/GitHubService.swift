/*
 * GitHubService.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/28.
 */

import Foundation

import GenericJSON
import ServiceKit
import UnwrapOrThrow

import OfficeKit2



public final class GitHubService : UserService {
	
	public static let providerID: String = "happn/github"
	
	public typealias UserType = GitHubUser
	
	public let id: String
	public let config: GitHubServiceConfig
	
	public let connector: GitHubConnector
	
	public convenience init(id: String, jsonConfig: JSON) throws {
		let config = try GitHubServiceConfig(json: jsonConfig)
		try self.init(id: id, gitHubServiceConfig: config)
	}
	
	public init(id: String, gitHubServiceConfig: GitHubServiceConfig) throws {
		self.id = id
		self.config = gitHubServiceConfig
		
		self.connector = try GitHubConnector(
			appID: gitHubServiceConfig.connectorSettings.appID,
			installationID: gitHubServiceConfig.connectorSettings.installationID,
			privateKeyPath: gitHubServiceConfig.connectorSettings.privateKeyPath
		)
	}
	
	public func shortDescription(fromUser user: GitHubUser) -> String {
		return "GitHubUser<\(user.login)>"
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
	
	public func json(fromUser user: GitHubUser) throws -> GenericJSON.JSON {
		return try JSON(encodable: user)
	}
	
	public func alternateIDs(fromUserID userID: String) -> (regular: String, other: Set<String>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> String {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromPersistentID pID: Int, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> GitHubUser? {
		try await connector.connectIfNeeded()
		return try await GitHubUser.get(id: pID, orgID: config.orgID, connector: connector)
	}
	
	public func existingUser(fromID uID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> GitHubUser? {
		try await connector.connectIfNeeded()
		return try await GitHubUser.get(login: uID, orgID: config.orgID, connector: connector)
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [GitHubUser] {
		try await connector.connectIfNeeded()
		return try await GitHubUser.list(orgID: config.orgID, connector: connector)
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: GitHubUser, using services: Services) async throws -> GitHubUser {
		try await connector.connectIfNeeded()
		return try await user.create(role: .directMember, orgID: config.orgID, connector: connector)
	}
	
	public let supportsUserUpdate: Bool = false
	public func updateUser(_ user: GitHubUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> GitHubUser {
		throw OfficeKitError.unsupportedOperation
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: GitHubUser, using services: Services) async throws {
		try await connector.connectIfNeeded()
		try await user.delete(orgID: config.orgID, connector: connector)
	}
	
	public let supportsPasswordChange: Bool = false
	public func changePassword(of user: GitHubUser, to newPassword: String, using services: Services) async throws {
		throw OfficeKitError.unsupportedOperation
	}
	
}
