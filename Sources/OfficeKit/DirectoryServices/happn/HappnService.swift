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
		return user.login ?? "<null user id>"
	}
	
	public func string(fromUserId userId: String?) -> String {
		return userId ?? "__officectl_internal__null_happn_id__"
	}
	
	public func userId(fromString string: String) throws -> String? {
		guard string != "__officectl_internal__null_happn_id__" else {
			return nil
		}
		return string
	}
	
	public func string(fromPersistentId pId: String) -> String {
		return pId
	}
	
	public func persistentId(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: HappnUser) throws -> JSON {
		#warning("TODO (Note: Goes with the TODO related to JSONEncoder in logicalUser from wrapped user below.)")
		return try JSON(encodable: user)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> HappnUser {
		let taggedId = userWrapper.userId
		if taggedId.tag == config.serviceId, let underlying = userWrapper.underlyingUser {
			/* The generic user is from our service! We should be able to translate
			 * if fully to our User type. */
			#warning("TODO: Not elegant. We should do better but I’m lazy rn")
			let encoded = try JSONEncoder().encode(underlying)
			return try JSONDecoder().decode(HappnUser.self, from: encoded)
			
		} else if taggedId.tag == config.serviceId {
			/* The generic user id from our service, but there is no underlying
			 * user… Let’s create a GoogleUser from the user id. */
			guard let email = Email(string: taggedId.id) else {
				throw InvalidArgumentError(message: "Got an invalid id for a HappnService user.")
			}
			return HappnUser(login: email.stringValue)
			
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create a GoogleUser")
			}
			let res = HappnUser(login: email.stringValue)
			#warning("Other properties…")
			return res
		}
	}
	
	public func existingUser(fromPersistentId pId: String, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<HappnUser?> {
		throw NotImplementedError()
	}
	
	public func existingUser(fromUserId uId: String?, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<HappnUser?> {
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
