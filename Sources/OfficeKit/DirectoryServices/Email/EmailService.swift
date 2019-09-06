/*
 * EmailService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/08/2019.
 */

import Foundation

import GenericJSON
import Service



public final class EmailService : DirectoryService {
	
	public static let providerId = "internal_email"
	
	public let config: EmailServiceConfig
	public let globalConfig: GlobalConfig
	
	public typealias ConfigType = EmailServiceConfig
	public typealias UserType = EmailUser
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(from user: EmailUser) -> String {
		return user.userId.stringValue
	}
	
	public func string(fromUserId userId: Email) -> String {
		return userId.stringValue
	}
	
	public func userId(fromString string: String) throws -> Email {
		guard let email = Email(string: string) else {
			throw InvalidArgumentError(message: "Malformed email \(string)")
		}
		return email
	}
	
	public func string(fromPersistentId pId: Email) -> String {
		return pId.stringValue
	}
	
	public func persistentId(fromString string: String) throws -> Email {
		guard let email = Email(string: string) else {
			throw InvalidArgumentError(message: "Malformed email \(string)")
		}
		return email
	}
	
	public func json(fromUser user: EmailUser) throws -> JSON {
		return .string(user.userId.stringValue)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper, hints: [DirectoryUserProperty: String?]) throws -> EmailUser {
		let taggedId = userWrapper.userId
		if taggedId.tag == config.serviceId {
			guard let email = Email(string: taggedId.id) else {
				throw InvalidArgumentError(message: "Got a generic user whose id comes from our service, but whose id is not a valid email string.")
			}
			return EmailUser(userId: email)
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the user to create an EmailUser")
			}
			return EmailUser(userId: email)
		}
	}
	
	public func existingUser(fromPersistentId pId: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<EmailUser?> {
		return container.eventLoop.newSucceededFuture(result: EmailUser(userId: pId))
	}
	
	public func existingUser(fromUserId uId: Email, propertiesToFetch: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<EmailUser?> {
		return container.eventLoop.newSucceededFuture(result: EmailUser(userId: uId))
	}
	
	public func listAllUsers(on container: Container) throws -> EventLoopFuture<[EmailUser]> {
		throw NotSupportedError()
	}
	
	public let supportsUserCreation = false
	public func createUser(_ user: EmailUser, on container: Container) throws -> EventLoopFuture<EmailUser> {
		throw NotSupportedError()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: EmailUser, propertiesToUpdate: Set<DirectoryUserProperty>, on container: Container) throws -> EventLoopFuture<EmailUser> {
		throw NotSupportedError()
	}
	
	public let supportsUserDeletion = false
	public func deleteUser(_ user: EmailUser, on container: Container) throws -> EventLoopFuture<Void> {
		throw NotSupportedError()
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: EmailUser, on container: Container) throws -> ResetPasswordAction {
		throw NotSupportedError()
	}

}
