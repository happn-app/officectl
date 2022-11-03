/*
 * EmailService.swift
 * EmailOfficeService
 *
 * Created by François Lamboley on 2022/11/02.
 */

import Foundation

import Email
import GenericJSON
import OfficeKit2
import ServiceKit



public final class EmailService : UserService {
	
	public static var providerID: String = "happn:email"
	
	public static var supportedUserProperties: Set<UserProperty> {
		return [.id, .emails]
	}
	
	public typealias UserType = EmailUser
	
	public let id: String
	
	public init(id: String, jsonConfig: JSON) throws {
		self.id = id
	}
	
	public func shortDescription(fromUser user: EmailUser) -> String {
		return user.id.rawValue
	}
	
	public func string(fromUserID userID: Email) -> String {
		return userID.rawValue
	}
	
	public func userID(fromString string: String) throws -> Email {
		guard let email = Email(rawValue: string) else {
			throw Err.invalidEmail(string)
		}
		return email
	}
	
	public func string(fromPersistentUserID pID: Never) -> String {
	}
	
	public func persistentUserID(fromString string: String) throws -> Never {
		throw Err.unsupportedOperation
	}
	
	public func json(fromUser user: EmailUser) throws -> JSON {
		return .string(user.id.rawValue)
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> EmailUser {
		guard let emailStr = json.stringValue, let email = Email(rawValue: emailStr) else {
			throw Err.invalidJSONRepresentation(json)
		}
		return EmailUser(id: email)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: UserWrapper) throws -> EmailUser {
		if userWrapper.sourceServiceID == id, let underlyingUser = userWrapper.underlyingUser {
			/* If the underlying user is invalid, we fail the conversion altogether.
			 * We could try and continue with the other properties of the wrapped user, but failing seems more appropriate (the wrapped user is effectively invalid). */
			return try Result{ try logicalUser(fromJSON: underlyingUser) }.mapError{ _ in Err.invalidWrappedUser(userWrapper) }.get()
		}
		
		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
		
		let inferredUserID: Email
		if userWrapper.sourceServiceID == id {
			/* The underlying user (though absent) is from our service; the original ID can be decoded as a valid ID for our service. */
			guard let email = Email(rawValue: userWrapper.id.id) else {
				throw Err.invalidWrappedUser(userWrapper)
			}
			inferredUserID = email
		} else {
//			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
			guard let email = userWrapper.emails?.onlyElement else {
				throw Err.invalidWrappedUser(userWrapper)
			}
			inferredUserID = email
		}
		
		return EmailUser(id: inferredUserID)
	}
	
	public func applyHints(_ hints: [UserProperty : String?], toUser user: inout EmailUser, allowUserIDChange: Bool) -> Set<UserProperty> {
		guard allowUserIDChange else {return []}
		
#warning("TODO: .emails hint is improperly handled.")
		let newEmailHintStr = hints[.emails].flatMap({ $0 }) ?? hints[.id].flatMap({ $0 })
		guard let newEmailStr = newEmailHintStr, let newEmail = Email(rawValue: newEmailStr) else {return []}
		
		user.id = newEmail
		return [.id, .emails]
	}
	
	public func existingUser(fromUserID uID: Email, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> EmailUser? {
		return EmailUser(id: uID)
	}
	
	public func existingUser(fromPersistentID pID: Never, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> EmailUser? {
	}
	
	public func listAllUsers(using services: Services) async throws -> [EmailUser] {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserCreation: Bool = false
	public func createUser(_ user: EmailUser, using services: Services) async throws -> EmailUser {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserUpdate: Bool = false
	public func updateUser(_ user: EmailUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> EmailUser {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserDeletion: Bool = false
	public func deleteUser(_ user: EmailUser, using services: Services) async throws {
		throw Err.unsupportedOperation
	}
	
	public let supportsPasswordChange: Bool = false
	public func changePassword(of user: EmailUser, to newPassword: String, using services: Services) throws {
		throw Err.unsupportedOperation
	}
	
}
