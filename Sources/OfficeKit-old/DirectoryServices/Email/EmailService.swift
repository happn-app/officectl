/*
 * EmailService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/26.
 */

import Foundation

import Email
import GenericJSON
import NIO
import ServiceKit



public final class EmailService : UserDirectoryService {
	
	public static let providerID = "internal_email"
	
	public let config: EmailServiceConfig
	public let globalConfig: GlobalConfig
	
	public typealias ConfigType = EmailServiceConfig
	public typealias UserType = EmailUser
	
	public init(config c: ConfigType, globalConfig gc: GlobalConfig) {
		config = c
		globalConfig = gc
	}
	
	public func shortDescription(fromUser user: EmailUser) -> String {
		return user.userID.rawValue
	}
	
	public func string(fromUserID userID: Email) -> String {
		return userID.rawValue
	}
	
	public func userID(fromString string: String) throws -> Email {
		guard let email = Email(rawValue: string) else {
			throw InvalidArgumentError(message: "Malformed email \(string)")
		}
		return email
	}
	
	public func string(fromPersistentUserID pID: Email) -> String {
		return pID.rawValue
	}
	
	public func persistentUserID(fromString string: String) throws -> Email {
		guard let email = Email(rawValue: string) else {
			throw InvalidArgumentError(message: "Malformed email \(string)")
		}
		return email
	}
	
	public func json(fromUser user: EmailUser) throws -> JSON {
		return .string(user.userID.rawValue)
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> EmailUser {
		guard let emailStr = json.stringValue, let email = Email(rawValue: emailStr) else {
			throw InvalidArgumentError(message: "Invalid json representing an EmailUser")
		}
		return EmailUser(userID: email)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: DirectoryUserWrapper) throws -> EmailUser {
		if userWrapper.sourceServiceID == config.serviceID, let underlyingUser = userWrapper.underlyingUser {
			return try logicalUser(fromJSON: underlyingUser)
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserID: Email
		if userWrapper.sourceServiceID == config.serviceID {
			/* The underlying user (though absent) is from our service; the original ID can be decoded as a valid ID for our service. */
			guard let email = Email(rawValue: userWrapper.userID.id) else {
				throw InvalidArgumentError(message: "Got a generic user whose ID comes from our service, but which does not have a valid email.")
			}
			inferredUserID = email
		} else {
			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
				throw InvalidArgumentError(message: "Cannot get an email from the wrapped user to create an EmailUser")
			}
			inferredUserID = email
		}
		
		return EmailUser(userID: inferredUserID)
	}
	
	public func applyHints(_ hints: [DirectoryUserProperty : String?], toUser user: inout EmailUser, allowUserIDChange: Bool) -> Set<DirectoryUserProperty> {
		guard allowUserIDChange else {return []}
		
		let newEmailHintStr = hints[.identifyingEmail].flatMap({ $0 }) ?? hints[.userID].flatMap({ $0 }) ?? hints[.persistentID].flatMap({ $0 })
		guard let newEmailStr = newEmailHintStr, let newEmail = Email(rawValue: newEmailStr) else {return []}
		
		user.userID = newEmail
		return [.userID, .persistentID, .identifyingEmail]
	}
	
	public func existingUser(fromPersistentID pID: Email, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> EmailUser? {
		return EmailUser(userID: pID)
	}
	
	public func existingUser(fromUserID uID: Email, propertiesToFetch: Set<DirectoryUserProperty>, using services: Services) async throws -> EmailUser? {
		return EmailUser(userID: uID)
	}
	
	public func listAllUsers(using services: Services) async throws -> [EmailUser] {
		throw NotSupportedError()
	}
	
	public let supportsUserCreation = false
	public func createUser(_ user: EmailUser, using services: Services) async throws -> EmailUser {
		throw NotSupportedError()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: EmailUser, propertiesToUpdate: Set<DirectoryUserProperty>, using services: Services) async throws -> EmailUser {
		throw NotSupportedError()
	}
	
	public let supportsUserDeletion = false
	public func deleteUser(_ user: EmailUser, using services: Services) async throws {
		throw NotSupportedError()
	}
	
	public let supportsPasswordChange = false
	public func changePasswordAction(for user: EmailUser, using services: Services) throws -> ResetPasswordAction {
		throw NotSupportedError()
	}
	
}
