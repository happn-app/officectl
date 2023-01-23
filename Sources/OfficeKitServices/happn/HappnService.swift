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
import UnwrapOrThrow
import URLRequestOperation

import CommonOfficePropertiesFromHappn
import OfficeKit
import OfficeModelCore
import ServiceKit



public final class HappnService : UserService {
	
	public static let providerID: String = "happn/happn"
	
	public typealias UserType = HappnUser
	
	public let id: Tag
	public let name: String
	public let config: HappnServiceConfig
	
	public let connector: HappnConnector
	
	public convenience init(id: Tag, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try HappnServiceConfig(json: jsonConfig)
		try self.init(id: id, name: name, happnServiceConfig: config)
	}
	
	public init(id: Tag, name: String, happnServiceConfig: HappnServiceConfig) throws {
		self.id = id
		self.name = name
		self.config = happnServiceConfig
		
		self.connector = HappnConnector(
			baseURL: config.connectorSettings.baseURL,
			clientID: config.connectorSettings.clientID,
			clientSecret: config.connectorSettings.clientSecret,
			username: config.connectorSettings.adminUsername,
			password: config.connectorSettings.adminPassword
		)
	}
	
	public func shortDescription(fromUser user: HappnUser) -> String {
		return "HappnUser<\(user.login)>"
	}
	
	public func string(fromUserID userID: HappnUserID) -> String {
		switch userID {
			case .nullLogin:    return "null:"
			case .login(let l): return "login:\(l.rawValue)"
		}
	}
	
	public func userID(fromString string: String) throws -> HappnUserID {
		let taggedID = try TaggedID(string) ?! Err.invalidID(string)
		if taggedID.id == "" {
			/* Either we have a null ID (tag will be "null", or we have a “maybe login but w/o a prefix”).
			 * We are lenient on IDs w/o the login tag and parse them anyway. */
			if taggedID.tag == "null" {
				return .nullLogin
			}
			return try .login(Email(rawValue: taggedID.tag.rawValue) ?! Err.invalidID(string))
		}
		switch taggedID.tag {
			case "login":
				return try .login(Email(rawValue: taggedID.id) ?! Err.invalidID(string))
				
			default:
				throw Err.invalidID(string)
		}
	}
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func alternateIDs(fromUserID userID: HappnUserID) -> (regular: HappnUserID, other: Set<HappnUserID>) {
		guard let email = userID.email else {
			return (userID, [])
		}
		let regular = email.primaryDomainVariant(aliasMap: config.domainAliases)
		let other = regular.allDomainVariants(aliasMap: config.domainAliases).subtracting([regular])
		return (.login(regular), Set(other.map{ .login($0) }))
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> HappnUserID {
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ Email(rawValue: $0) }
			.map{ HappnUserID.login($0) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromID uID: HappnUserID, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> HappnUser? {
		try await connector.increaseScopeIfNeeded("admin_read", "admin_search_user")
		
		let users: [HappnUser]
		switch uID {
			case .nullLogin:
				/* Very inefficient, but I don’t think happn’s API can search for users with a null ID. */
				users = try await listAllUsers(includeSuspended: true, propertiesToFetch: propertiesToFetch, using: services)
					.filter{ $0.login == .nullLogin }
				
			case .login(let l):
				let ids = Set(l.allDomainVariants(aliasMap: config.domainAliases))
				users = try await ids.asyncFlatMap{ try await HappnUser.search(text: $0.rawValue, propertiesToFetch: HappnUser.keysFromProperties(propertiesToFetch), connector: connector) }
		}
		
		guard users.count <= 1 else {
			throw OfficeKitError.tooManyUsersFromAPI(users: users)
		}
		return users.first
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> HappnUser? {
		try await connector.increaseScopeIfNeeded("admin_read")
		
		let ret = try await HappnUser.get(id: pID, propertiesToFetch: HappnUser.keysFromProperties(propertiesToFetch), connector: connector)
		/* happn’s API happily returns a user for a non-existing ID!
		 * Except all the fields (apart from id) are nil.
		 *
		 * We’ll detect these invalid user by checking the firstName (which we always ask in the fields).
		 * The first name cannot be nil for a valid user AFAIK, so a nil first name indicates an invalid user. */
		guard ret?.firstName != nil else {
			return nil
		}
		return ret
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> [HappnUser] {
		try await connector.increaseScopeIfNeeded("admin_read", "admin_search_user")
		let forcedProperty: Set<UserProperty> = (!includeSuspended ? [.isSuspended] : [])
		let users = try await HappnUser.search(text: nil, propertiesToFetch: HappnUser.keysFromProperties(propertiesToFetch?.union(forcedProperty)), connector: connector)
		if !includeSuspended {return users.filter{ !($0.oU_isSuspended ?? false) }}
		else                 {return users}
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
			user.password = String.generatePassword()
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
		_ = try await updateUser(user, propertiesToUpdate: [.id, .init(rawValue: "happn/password")], using: services)
	}
	
}
