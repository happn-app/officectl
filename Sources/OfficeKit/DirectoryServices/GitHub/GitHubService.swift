/*
 * GitHubService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Async
import SemiSingleton
import Service



public final class GitHubService : DirectoryService {
	
	public static let providerId = "internal_github"
	
	public typealias ConfigType = GitHubServiceConfig
	public typealias UserType = GitHubUser
	
	public let config: GitHubServiceConfig
	
	public init(config c: GitHubServiceConfig) {
		config = c
	}
	
	public func shortDescription(from user: GitHubUser) -> String {
		return user.userId
	}
	
	public func string(fromUserId userId: String) -> String {
		return userId
	}
	
	public func userId(fromString string: String) throws -> String {
		return string
	}
	
	public func genericUser(fromUser user: GitHubUser) throws -> GenericDirectoryUser {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromGenericUser genericUser: GenericDirectoryUser) throws -> GitHubUser {
		throw NotImplementedError()
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GitHubUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GitHubUser?> {
		throw NotImplementedError()
	}
	
	public func listAllUsers(on container: Container) throws -> Future<[GitHubUser]> {
		throw NotImplementedError()
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: GitHubUser, on container: Container) throws -> Future<GitHubUser> {
		throw NotImplementedError()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: GitHubUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GitHubUser> {
		throw NotSupportedError(message: "Not sure what updating a user would mean for GitHub as the users use personal accounts.")
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: GitHubUser, on container: Container) throws -> Future<Void> {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: GitHubUser, on container: Container) throws -> ResetPasswordAction {
		throw NotSupportedError(message: "Cannot change the user’s password on GitHub as users use their personal accounts.")
	}
	
}
