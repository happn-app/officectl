/*
 * GoogleService.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/24.
 */

import Foundation

import Crypto
import Email
import GenericJSON
import Logging
import OfficeKit2
import ServiceKit



public final class GoogleService : UserService {
	
	public static let providerID: String = "happn/google"
	
	public static var supportedUserProperties: Set<UserProperty> {
		return Set(GoogleUser.propertyToKeys.filter{ !$0.value.isEmpty }.map{ $0.key })
	}
	
	public typealias UserType = GoogleUser
	
	public let id: String
	public let config: GoogleServiceConfig
	
	public let connector: GoogleConnector
	
	public init(id: String, jsonConfig: JSON) throws {
		self.id = id
		self.config = try GoogleServiceConfig(json: jsonConfig)
		
		self.connector = try GoogleConnector(
			jsonCredentialsURL: URL(fileURLWithPath: config.connectorSettings.superuserJSONCredsPath),
			userBehalf: config.connectorSettings.adminEmail?.rawValue
		)
	}
	
	public func shortDescription(fromUser user: GoogleUser) -> String {
		return user.primaryEmail.rawValue
	}
	
	public func string(fromUserID userID: Email) -> String {
		return userID.rawValue
	}
	
	public func userID(fromString string: String) throws -> Email {
		guard let e = Email(rawValue: string) else {
			throw Err.invalidEmail(string)
		}
		return e
	}
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func json(fromUser user: GoogleUser) throws -> JSON {
		return try JSON(encodable: user)
	}
	
	public func logicalUser<OtherUserType>(fromUser user: OtherUserType) throws -> GoogleUser where OtherUserType : User {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ Email(rawValue: $0) }
			.first{ _ in true } /* Not a simple `.first` because of https://stackoverflow.com/a/71778190 (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotCreateLogicalUserFromOtherUser
		}
		
		var ret = GoogleUser(email: id)
		ret.name = GoogleUser.Name(givenName: user.oU_firstName, familyName: user.oU_lastName)
		/* TODO: Other properties. */
		return ret
	}
	
	public func applyHints(_ hints: [UserProperty : String?], toUser user: inout GoogleUser, allowUserIDChange: Bool) -> Set<UserProperty> {
		let primaryEmailProperty = UserProperty("primaryEmail")
		
		var ret = Set<UserProperty>()
		for (property, newValue) in hints {
			let touchedKey: Bool
			switch property {
				case .id, primaryEmailProperty:
					guard allowUserIDChange else {continue}
					guard let newValue else {
						Conf.logger?.error("Asked to remove the id of a user (nil value for id in hints). This is illegal, I’m not doing it.")
						continue
					}
					touchedKey = GoogleUser.setValueIfNeeded(newValue, in: &user.primaryEmail)
					if touchedKey {
						/* We add both.
						 * `property` will be added twice, but that’s not a problem. */
						ret.insert(.id)
						ret.insert(primaryEmailProperty)
					}
					
				case .firstName: touchedKey = GoogleUser.setValueIfNeeded(GoogleUser.Name(givenName: newValue,             familyName: user.name?.familyName), in: &user.name)
				case .lastName:  touchedKey = GoogleUser.setValueIfNeeded(GoogleUser.Name(givenName: user.name?.givenName, familyName: newValue),              in: &user.name)
				case .password:
					if let newValue {
						let hashed = Insecure.SHA1.hash(data: Data(newValue.utf8)).reduce("", { $0 + String(format: "%02x", $1) })
						touchedKey = (user.password != hashed || user.passwordHashFunction != .sha1)
						user.password = hashed
						user.passwordHashFunction = .sha1
						user.changePasswordAtNextLogin = false
					} else {
						touchedKey = (user.password != nil || user.passwordHashFunction != nil)
						user.password = nil
						user.passwordHashFunction = nil
						user.changePasswordAtNextLogin = nil
					}
				/* TODO: Other properties. */
				default:         touchedKey = false
			}
			if touchedKey {
				ret.insert(property)
			}
		}
		return ret
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> GoogleUser? {
		logSuspensionWarning(using: services)
		
		try await connector.increaseScopeIfNeeded("https://www.googleapis.com/auth/admin.directory.user")
		let ret = try await GoogleUser.get(id: pID, propertiesToFetch: GoogleUser.keysFromProperties(propertiesToFetch), connector: connector)
		if ret?.isSuspended ?? true {
			return nil
		}
		return ret
	}
	
	public func existingUser(fromID uID: Email, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> GoogleUser? {
		/* Gougle returns the user whether from persistent or standard id. */
		return try await existingUser(fromPersistentID: uID.rawValue, propertiesToFetch: propertiesToFetch, using: services)
	}
	
	public func listAllUsers(propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [GoogleUser] {
		logSuspensionWarning(using: services)
		throw Err.unsupportedOperation
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: GoogleUser, using services: Services) async throws -> GoogleUser {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserUpdate: Bool = true
	public func updateUser(_ user: GoogleUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> GoogleUser {
		throw Err.unsupportedOperation
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: GoogleUser, using services: Services) async throws {
		throw Err.unsupportedOperation
	}
	
	public let supportsPasswordChange: Bool = true
	public func changePassword(of user: GoogleUser, to newPassword: String, using services: Services) async throws {
		throw Err.unsupportedOperation
	}
	
	private static var hasLoggedSuspensionWarning = false
	private func logSuspensionWarning(using services: Services) {
		guard !Self.hasLoggedSuspensionWarning else {
			return
		}
		(try? services.make(Logger.self))?.warning("Note: Only non-suspended users are returned from the google service. This will be logged only once.")
		Self.hasLoggedSuspensionWarning = true
	}
	
}
