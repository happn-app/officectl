/*
 * GitHubService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/20.
 */

import Foundation

import GenericJSON
import NIO
import SemiSingleton
import ServiceKit



public final class GitHubService : UserDirectoryService {
	
	public static let providerId = "internal_github"
	
	public typealias ConfigType = GitHubServiceConfig
	public typealias UserType = GitHubUser
	
	public let config: GitHubServiceConfig
	public let globalConfig: GlobalConfig
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(fromUser user: GitHubUser) -> String {
		return user.userId
	}
	
	public func string(fromUserId userId: String) -> String {
		return userId
	}
	
	public func userId(fromString string: String) throws -> String {
		return string
	}
	
	public func string(fromPersistentUserId pId: String) -> String {
		return pId
	}
	
	public func persistentUserId(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: GitHubUser) throws -> JSON {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> GitHubUser {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> GitHubUser {
		if userWrapper.sourceServiceId == config.serviceId, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		throw NotImplementedError()
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout GitHubUser, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		return []
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> GitHubUser? {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: String, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> GitHubUser? {
		throw NotImplementedError()
	}
	
	public func listAllUsers(using services: Services) async throws -> [GitHubUser] {
		throw NotImplementedError()
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: GitHubUser, using services: Services) async throws -> GitHubUser {
		throw NotImplementedError()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: GitHubUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> GitHubUser {
		throw NotSupportedError(message: "Not sure what updating a user would mean for GitHub as the users use personal accounts.")
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: GitHubUser, using services: Services) async throws {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: GitHubUser, using services: Services) throws -> ResetPasswordAction {
		throw NotSupportedError(message: "Cannot change the user’s password on GitHub as users use their personal accounts.")
	}
	
}
