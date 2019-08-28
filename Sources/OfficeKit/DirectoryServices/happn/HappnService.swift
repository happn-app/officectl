/*
 * HappnService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/08/2019.
 */

import Foundation

import GenericJSON
import NIO
import Vapor



public final class HappnService : DirectoryService {
	
	public static var providerId = "internal_happn"
	
	public typealias ConfigType = HappnServiceConfig
	public typealias UserType = HappnUser
	
	public let config: HappnServiceConfig
	public let globalConfig: GlobalConfig
	
	public init(config c: HappnServiceConfig, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(from user: HappnUser) -> String {
		return user.login
	}
	
	public func string(fromUserId userId: String) -> String {
		return userId
	}
	
	public func userId(fromString string: String) throws -> String {
		return string
	}
	
	public func string(fromPersistentId pId: String) -> String {
		return pId
	}
	
	public func persistentId(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: HappnUser) throws -> JSON {
		throw NotImplementedError()
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> HappnUser {
		throw NotImplementedError()
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<HappnUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<HappnUser?> {
		throw NotImplementedError()
	}
	
	public func listAllUsers(on container: Container) throws -> EventLoopFuture<[HappnUser]> {
		throw NotImplementedError()
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: HappnUser, on container: Container) throws -> EventLoopFuture<HappnUser> {
		throw NotImplementedError()
	}
	
	public let supportsUserUpdate = true
	public func updateUser(_ user: HappnUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<HappnUser> {
		throw NotImplementedError()
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: HappnUser, on container: Container) throws -> EventLoopFuture<Void> {
		throw NotImplementedError()
	}
	
	public let supportsPasswordChange = true
	public func changePasswordAction(for user: HappnUser, on container: Container) throws -> ResetPasswordAction {
		throw NotImplementedError()
	}

}
