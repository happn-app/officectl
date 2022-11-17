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
	
	public static var providerID: String = "happn/happn"
	
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
		return user.login.rawValue
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
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: HappnUser) throws -> JSON {
		return try JSON(encodable: user)
	}
	
	public func logicalUser(fromWrappedUser userWrapper: UserWrapper) throws -> HappnUser {
		struct NotImplemented : Error {}
		throw NotImplemented()
//		if userWrapper.sourceServiceID == id, let underlyingUser = userWrapper.underlyingUser {
//			/* If the underlying user is invalid, we fail the conversion altogether.
//			 * We could try and continue with the other properties of the wrapped user, but failing seems more appropriate (the wrapped user is effectively invalid). */
//			return try Result{ try logicalUser(fromJSON: underlyingUser) }.mapError{ _ in Err.invalidWrappedUser(userWrapper) }.get()
//		}
//
//		/* *** No underlying user from our service. We infer the user from the generic properties of the wrapped user. *** */
//
//		let inferredUserID: Email
//		if userWrapper.sourceServiceID == id {
//			/* The underlying user (though absent) is from our service; the original ID can be decoded as a valid ID for our service. */
//			guard let email = Email(rawValue: userWrapper.id.id) else {
//				throw Err.invalidWrappedUser(userWrapper)
//			}
//			inferredUserID = email
//		} else {
//			//			guard let email = userWrapper.mainEmail(domainMap: globalConfig.domainAliases) else {
//			guard let email = userWrapper.emails?.onlyElement else {
//				throw Err.invalidWrappedUser(userWrapper)
//			}
//			inferredUserID = email
//		}
//
//		return HappnUser(id: inferredUserID)
	}
	
	public func applyHints(_ hints: [UserProperty : String?], toUser user: inout HappnUser, allowUserIDChange: Bool) -> Set<UserProperty> {
		let loginProperty = UserProperty("login")
		
		var ret = Set<UserProperty>()
		for (property, newValue) in hints {
			let touchedKey: Bool
			switch property {
				case .id, loginProperty:
					guard allowUserIDChange else {continue}
					guard let newValue else {
						Conf.logger?.error("Asked to remove the id of a user (nil value for id in hints). This is illegal, I’m not doing it.")
						continue
					}
					touchedKey = HappnUser.setValueIfNeeded(newValue, in: &user.login)
					if touchedKey {
						/* We add both.
						 * `property` will be added twice, but that’s not a problem. */
						ret.insert(.id)
						ret.insert(loginProperty)
					}
					
				case .firstName: touchedKey = HappnUser.setValueIfNeeded(newValue, in: &user.firstName)
				case .lastName:  touchedKey = HappnUser.setValueIfNeeded(newValue, in: &user.lastName)
				case .nickname:  touchedKey = HappnUser.setValueIfNeeded(newValue, in: &user.nickname)
				case .gender:    touchedKey = HappnUser.setValueIfNeeded(newValue, in: &user.gender)
				case .birthdate: touchedKey = HappnUser.setValueIfNeeded(newValue, in: &user.birthDate, converter: { HappnUser.birthDateFormatter.date(from: $0) })
				case .password:  touchedKey = HappnUser.setValueIfNeeded(newValue, in: &user.password)
				default:         touchedKey = false
			}
			if touchedKey {
				ret.insert(property)
			}
		}
		return ret
	}
	
	public func existingUser(fromUserID uID: Email, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> HappnUser? {
		throw Err.unsupportedOperation
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> HappnUser? {
		throw Err.unsupportedOperation
	}
	
	public func listAllUsers(using services: Services) async throws -> [HappnUser] {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: HappnUser, using services: Services) async throws -> HappnUser {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: HappnUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> HappnUser {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: HappnUser, using services: Services) async throws {
		throw Err.unsupportedOperation
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: HappnUser, to newPassword: String, using services: Services) throws {
		throw Err.unsupportedOperation
	}
	
}
