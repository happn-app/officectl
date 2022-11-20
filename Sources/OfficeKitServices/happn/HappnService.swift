/*
 * HappnService.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation

import CollectionConcurrencyKit
import Email
import GenericJSON
import URLRequestOperation

import CommonOfficePropertiesFromHappn
import OfficeKit2
import ServiceKit



public final class HappnService : UserService {
	
	public static var providerID: String = "happn/happn"
	
	public static var supportedUserProperties: Set<UserProperty> {
		return [.id, .emails, .firstName, .lastName, .nickname, .password, .gender, .birthdate]
	}
	
	public typealias UserType = HappnUser
	
	public let id: String
	public let config: HappnServiceConfig
	
	public let connector: HappnConnector
	
	public init(id: String, jsonConfig: JSON) throws {
		self.id = id
		self.config = try HappnServiceConfig(json: jsonConfig)
		
		self.connector = HappnConnector(
			baseURL: config.connectorSettings.baseURL,
			clientID: config.connectorSettings.clientID,
			clientSecret: config.connectorSettings.clientSecret,
			username: config.connectorSettings.adminUsername,
			password: config.connectorSettings.adminPassword
		)
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
				case .birthdate: touchedKey = HappnUser.setValueIfNeeded(newValue, in: &user.birthDate, converter: { HappnBirthDateWrapper.birthDateFormatter.date(from: $0) })
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
		try await connector.increaseScopeIfNeeded("admin_read", "admin_search_user")
		
#warning("TODO: domain variants")
		let ids = /*Set(*/[uID]/*.allDomainVariants(aliasMap: self.globalConfig.domainAliases))*/
#warning("TODO: properties to fetch")
		let users = try await ids.asyncFlatMap{ try await HappnUser.search(text: $0.rawValue, propertiesToFetch: [], connector: connector) }
		guard users.count <= 1 else {
			throw Err.tooManyUsersFromAPI(id: uID)
		}
		
		return users.first
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> HappnUser? {
		try await connector.increaseScopeIfNeeded("admin_read")
		
		do {
#warning("TODO: properties to fetch")
			return try await HappnUser.get(id: pID, propertiesToFetch: [], connector: connector)
		} catch let error as URLRequestOperationError {
			/* happn’s API happily returns a user for a non-existing ID!
			 * Except all the fields (apart from id) are nil.
			 * We’ll detect if the error was a decoding error for the path data.login because a nil login is not possible,
			 *  so the user does not exist if we get this error. */
			guard
				let decodeError = error.postProcessError as? DecodeHTTPContentResultProcessorError,
				case let .dataConversionFailed(_, decodeError as DecodingError) = decodeError,
				case let .valueNotFound(type, context) = decodeError
			else {
				throw error
			}
			let codingPathStr = context.codingPath.map{ $0.stringValue }
			let expectedCodingPathStr = [ApiResult<HappnUser>.CodingKeys.data.stringValue, HappnUser.CodingKeys.login.stringValue]
			/* Note: We also check the expected type was a String though it’s most like not useful. */
			guard type == String.self, codingPathStr == expectedCodingPathStr else {
				throw error
			}
			return nil
		}
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
