/*
 * EmailService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/08/2019.
 */

import Foundation

import GenericJSON
import NIO
import ServiceKit



public final class EmailService : UserDirectoryService {
	
	public static let providerId = "internal_email"
	
	public let config: EmailServiceConfig
	public let globalConfig: GlobalConfig
	
	public typealias ConfigType = EmailServiceConfig
	public typealias UserType = EmailUser
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(fromUser user: EmailUser) -> String {
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
	
	public func string(fromPersistentUserId pId: Email) -> String {
		return pId.stringValue
	}
	
	public func persistentUserId(fromString string: String) throws -> Email {
		guard let email = Email(string: string) else {
			throw InvalidArgumentError(message: "Malformed email \(string)")
		}
		return email
	}
	
	public func json(fromUser user: EmailUser) throws -> JSON {
		return .string(user.userId.stringValue)
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> EmailUser {
		guard let emailStr = json.stringValue, let email = Email(string: emailStr) else {
			throw InvalidArgumentError(message: "Invalid json representing an EmailUser")
		}
		return EmailUser(userId: email)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> EmailUser {
		if userWrapper.sourceServiceId == config.serviceId, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserId: Email
		if userWrapper.sourceServiceId == config.serviceId {
			/* The underlying user (though absent) is from our service; the
			 * original id can be decoded as a valid id for our service. */
			guard let email = Email(string: userWrapper.userId.id) else {
				throw InvalidArgumentError(message: "Got a generic user whose id comes from our service, but which does not have a valid email.")
			}
			inferredUserId = email
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the wrapped user to create an EmailUser")
			}
			inferredUserId = email
		}
		
		return EmailUser(userId: inferredUserId)
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout EmailUser, allowUserIdChange: Bool) -> Set<DirectoryUserProperty> {
		guard allowUserIdChange else {return []}
		
		let newEmailHintStr = hints[.identifyingEmail].flatMap({ $0 }) ?? hints[.userId].flatMap({ $0 }) ?? hints[.persistentId].flatMap({ $0 })
		guard let newEmailStr = newEmailHintStr, let newEmail = Email(string: newEmailStr) else {return []}
		
		user.userId = newEmail
		return [.userId, .persistentId, .identifyingEmail]
	}
	
	public func existingUser(fromPersistentId pId: Email, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<EmailUser?> {
		let eventLoop = try services.eventLoop()
		return eventLoop.makeSucceededFuture(EmailUser(userId: pId))
	}
	
	public func existingUser(fromUserId uId: Email, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<EmailUser?> {
		let eventLoop = try services.eventLoop()
		return eventLoop.makeSucceededFuture(EmailUser(userId: uId))
	}
	
	public func listAllUsers(using services: Services) throws -> EventLoopFuture<[EmailUser]> {
		throw NotSupportedError()
	}
	
	public let supportsUserCreation = false
	public func createUser(_ user: EmailUser, using services: Services) throws -> EventLoopFuture<EmailUser> {
		throw NotSupportedError()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: EmailUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) throws -> EventLoopFuture<EmailUser> {
		throw NotSupportedError()
	}
	
	public let supportsUserDeletion = false
	public func deleteUser(_ user: EmailUser, using services: Services) throws -> EventLoopFuture<Void> {
		throw NotSupportedError()
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: EmailUser, using services: Services) throws -> ResetPasswordAction {
		throw NotSupportedError()
	}

}
