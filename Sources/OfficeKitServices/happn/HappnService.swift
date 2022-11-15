/*
 * HappnService.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation

import Email
import GenericJSON
import ServiceKit

import CommonOfficePropertiesFromHappn
import OfficeKit2



public final class HappnService : UserService {
	
	public static var providerID: String = "happn:happn"
	
	public static var supportedUserProperties: Set<UserProperty> {
		return [.id, .emails, .firstName, .lastName, .nickname, .password, .gender, .birthdate]
	}
	
	public typealias UserType = HappnUser
	
	public let id: String
	public let config: HappnServiceConfig
	
	public init(id: String, jsonConfig: JSON) throws {
		self.id = id
		self.config = try HappnServiceConfig(json: jsonConfig)
	}
	
	public func shortDescription(fromUser user: HappnUser) -> String {
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
	
	public func json(fromUser user: HappnUser) throws -> JSON {
		return .string(user.id.rawValue)
	}
	
	public func logicalUser(fromJSON json: JSON) throws -> HappnUser {
		guard let emailStr = json.stringValue, let email = Email(rawValue: emailStr) else {
			throw Err.invalidJSONRepresentation(json)
		}
		return HappnUser(id: email)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: UserWrapper) throws -> HappnUser {
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
		
		return HappnUser(id: inferredUserID)
	}
	
	public func applyHints(_ hints: [UserProperty : String?], toUser user: inout HappnUser, allowUserIDChange: Bool) -> Set<UserProperty> {
		guard allowUserIDChange else {return []}
		
#warning("TODO: .emails hint is improperly handled.")
		let newEmailHintStr = hints[.emails].flatMap({ $0 }) ?? hints[.id].flatMap({ $0 })
		guard let newEmailStr = newEmailHintStr, let newEmail = Email(rawValue: newEmailStr) else {return []}
		
		user.id = newEmail
		return [.id, .emails]
	}
	
	public func existingUser(fromUserID uID: Email, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> HappnUser? {
		return HappnUser(id: uID)
	}
	
	public func existingUser(fromPersistentID pID: Never, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> HappnUser? {
	}
	
	public func listAllUsers(using services: Services) async throws -> [HappnUser] {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserCreation: Bool = false
	public func createUser(_ user: HappnUser, using services: Services) async throws -> HappnUser {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserUpdate: Bool = false
	public func updateUser(_ user: HappnUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> HappnUser {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserDeletion: Bool = false
	public func deleteUser(_ user: HappnUser, using services: Services) async throws {
		throw Err.unsupportedOperation
	}
	
	public let supportsPasswordChange: Bool = false
	public func changePassword(of user: HappnUser, to newPassword: String, using services: Services) throws {
		throw Err.unsupportedOperation
	}
	
}
