/*
 * GitHubService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Async
import SemiSingleton



public final class GitHubService : DirectoryService {
	
	public static let providerId = "internal_github"
	
	public typealias UserType = GitHubUser
	
	public let serviceConfig: GitHubServiceConfig
	
	public init(config: GitHubServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceConfig = config
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		gitHubConnector = try sms.semiSingleton(forKey: config.connectorSettings)
	}
	
	public func logicalUser(from email: Email) throws -> GitHubUser {
		throw NotSupportedError(message: "There are no logical rules to convert an email to a GitHub user.")
	}
	
	public func logicalUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType) throws -> GitHubUser {
		throw NotSupportedError(message: "There are no logical rules to convert a user from a \(OtherServiceType.self) to a GitHub user.")
	}
	
	public func existingUser(from email: Email, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<GitHubUser?> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotSupportedError(message: "Fetching a GitHub user id from his email does not make sense as the user have his personal email in GitHub (and we probably don’t have access to the user’s emails anyway)."))
	}
	
	public func existingUser<OtherServiceType : DirectoryService>(from user: OtherServiceType.UserType, in service: OtherServiceType, propertiesToFetch: Set<DirectoryUserProperty>) -> Future<GitHubUser?> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: GitHubUser) -> Future<GitHubUser> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: GitHubUser, propertiesToUpdate: Set<DirectoryUserProperty>) -> Future<GitHubUser> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotSupportedError(message: "Not sure what updating a user would mean for GitHub as the users use personal accounts."))
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: GitHubUser) -> EventLoopFuture<Void> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: GitHubUser) throws -> ResetPasswordAction {
		throw NotSupportedError(message: "Cannot change the user’s password on GitHub as users use their personal accounts.")
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let asyncConfig: AsyncConfig
	private let semiSingletonStore: SemiSingletonStore
	
	private let gitHubConnector: GitHubJWTConnector
	
}
