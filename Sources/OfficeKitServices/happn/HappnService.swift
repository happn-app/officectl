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
	
	public static let providerID: String = "happn/happn"
	
	public static var supportedUserProperties: Set<UserProperty> {
		return Set(HappnUser.propertyToKeys.filter{ !$0.value.isEmpty }.map{ $0.key })
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
	
	public func logicalUser<OtherUserType>(fromUser user: OtherUserType) throws -> HappnUser where OtherUserType : User {
		let id = config.userIDBuilders.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ Email(rawValue: $0) }
			.first{ _ in true } /* Not a simple `.first` because of https://stackoverflow.com/a/71778190 (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotCreateLogicalUserFromOtherUser
		}
		
		var ret = HappnUser(login: id)
		ret.firstName = user.oU_firstName
		ret.lastName = user.oU_lastName
		ret.nickname = user.oU_nickname
		ret.gender = user.valueForProperty(.gender) as? Gender
		ret.birthDate = user.valueForProperty(.birthdate) as? Date
		return ret
	}
	
	public func applyHints(_ hints: [UserProperty : String?], toUser user: inout HappnUser, allowUserIDChange: Bool) -> Set<UserProperty> {
		var ret = Set<UserProperty>()
		for (property, newValue) in hints {
			let touchedKey: Bool
			switch property {
				case .id, UserProperty("login"):
					guard allowUserIDChange else {continue}
					Conf.logger?.error("Changing the id of a happn user is not supported by the happn API.")
					touchedKey = false
					
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
	
	public func existingUser(fromID uID: Email, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> HappnUser? {
		try await connector.increaseScopeIfNeeded("admin_read", "admin_search_user")
		
		let ids = Set(uID.allDomainVariants(aliasMap: config.domainAliases))
		let users = try await ids.asyncFlatMap{ try await HappnUser.search(text: $0.rawValue, propertiesToFetch: HappnUser.keysFromProperties(propertiesToFetch), connector: connector) }
		guard users.count <= 1 else {
			throw Err.tooManyUsersFromAPI(id: uID)
		}
		
		return users.first
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> HappnUser? {
		try await connector.increaseScopeIfNeeded("admin_read")
		
		do {
			return try await HappnUser.get(id: pID, propertiesToFetch: HappnUser.keysFromProperties(propertiesToFetch), connector: connector)
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
	
	public func listAllUsers(propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [HappnUser] {
		try await connector.increaseScopeIfNeeded("admin_read", "admin_search_user")
		return try await HappnUser.search(text: nil, propertiesToFetch: HappnUser.keysFromProperties(propertiesToFetch), connector: connector)
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: HappnUser, using services: Services) async throws -> HappnUser {
		try await connector.increaseScopeIfNeeded("admin_create", "user_create")
		
		var user = user
		if user.password == nil {
			/* Creating a user without a password is not possible.
			 * Let’s generate a password!
			 * A long and complex one. */
			OfficeKitConfig.logger?.warning("Auto-generating a random password for happn user creation: creating a happn user w/o a password is not supported.")
			let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=+_-$!@#%^&*(){}[]'\\\";:/?.>,<§"
			user.password = String((0..<64).map{ _ in chars.randomElement()! })
		}
		
		return try await user.create(connector: connector)
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: HappnUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> HappnUser {
		try await connector.increaseScopeIfNeeded("admin_read", "all_user_update")
		return try await user.update(properties: HappnUser.keysFromProperties(propertiesToUpdate), connector: connector)
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: HappnUser, using services: Services) async throws {
		try await connector.increaseScopeIfNeeded("admin_create"/* 😱🤷‍♂️ */, "admin_delete", "all_user_delete")
		return try await user.delete(connector: connector)
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: HappnUser, to newPassword: String, using services: Services) async throws {
		var user = user
		user.password = newPassword
		_ = try await updateUser(user, propertiesToUpdate: [.id, .password], using: services)
	}
	
}
