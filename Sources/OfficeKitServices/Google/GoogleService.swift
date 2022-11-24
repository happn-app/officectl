/*
 * GoogleService.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/24.
 */

import Foundation

import Email
import GenericJSON
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
		throw Err.unsupportedOperation
	}
	
	public func applyHints(_ hints: [UserProperty : String?], toUser user: inout GoogleUser, allowUserIDChange: Bool) -> Set<UserProperty> {
		return []
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> GoogleUser? {
		throw Err.unsupportedOperation
	}
	
	public func existingUser(fromID uID: Email, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> GoogleUser? {
		throw Err.unsupportedOperation
	}
	
	public func listAllUsers(propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [GoogleUser] {
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
}
