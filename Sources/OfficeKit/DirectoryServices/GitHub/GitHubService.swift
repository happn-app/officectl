/*
 * GitHubService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Async
import GenericJSON
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
	
	public func string(fromUserId userId: String) -> String {
		return userId
	}
	
	public func userId(fromString string: String) throws -> String {
		return string
	}
	
	public func shortDescription(from user: GitHubUser) -> String {
		return user.userId
	}
	
	public func exportableJSON(from user: GitHubUser) throws -> JSON {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromPersistentId pId: String, hints: [DirectoryUserProperty : Any]) throws -> GitHubUser {
		throw NotSupportedError(message: "It is not possible to create a GitHub user from its persistent id without fetching it.")
	}
	
	public func logicalUser(fromUserId uId: String, hints: [DirectoryUserProperty : Any]) throws -> GitHubUser {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromEmail email: Email, hints: [DirectoryUserProperty: Any]) throws -> GitHubUser {
		throw NotSupportedError(message: "There are no logical rules to convert an email to a GitHub user.")
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(fromUser user: OtherServiceType.UserType, in service: OtherServiceType, hints: [DirectoryUserProperty: Any]) throws -> GitHubUser {
		if service.config.serviceId == config.serviceId, let user: UserType = user.unboxed() {
			/* The given user is already from our service; let’s return it. */
			return user
		}
		
		#warning("TODO: Actually error thrown below is not necessarily true… we can setup a custom property in LDAP to set the GitHub user id of a user.")
		throw NotSupportedError(message: "There are no logical rules to convert a user from a \(OtherServiceType.self) to a GitHub user.")
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GitHubUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GitHubUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromEmail email: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GitHubUser?> {
		throw NotSupportedError(message: "Fetching a GitHub user id from his email does not make sense as the user have his personal email in GitHub (and we probably don’t have access to the user’s emails anyway).")
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> Future<GitHubUser?> {
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