/*
 * CloudflareZeroTrustService.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/21.
 */

import Foundation

import GenericJSON
import OfficeModelCore
import UnwrapOrThrow

import OfficeKit



public final class CloudflareZeroTrustService : UserService {
	
	public static let providerID: String = "happn/cloudflare-zerotrust"
	
	public typealias UserType = CloudflareZeroTrustUser
	
	public let id: Tag
	public let name: String
	public let config: CloudflareZeroTrustServiceConfig
	
	public let authenticator: CloudflareAuthenticator
	
	public convenience init(id: Tag, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try CloudflareZeroTrustServiceConfig(json: jsonConfig)
		try self.init(id: id, name: name, cloudflareZeroTrustServiceConfig: config, workdir: workdir)
	}
	
	public init(id: Tag, name: String, cloudflareZeroTrustServiceConfig: CloudflareZeroTrustServiceConfig, workdir: URL?) throws {
		self.id = id
		self.name = name
		self.config = cloudflareZeroTrustServiceConfig
		
		self.authenticator = CloudflareAuthenticator(token: cloudflareZeroTrustServiceConfig.connectorSettings.token)
	}
	
	public func shortDescription(fromUser user: CloudflareZeroTrustUser) -> String {
		return user.oU_id.rawValue
	}
	
	public func string(fromUserID userID: CloudflareZeroTrustUser.ID) -> String {
		return userID.rawValue
	}
	
	public func userID(fromString string: String) throws -> CloudflareZeroTrustUser.ID {
		return try .init(rawValue: string) ?! Err.invalidID(string)
	}
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func alternateIDs(fromUserID userID: CloudflareZeroTrustUser.ID) -> (regular: CloudflareZeroTrustUser.ID, other: Set<CloudflareZeroTrustUser.ID>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType : User>(fromUser user: OtherUserType) throws -> CloudflareZeroTrustUser.ID {
		if let user = user as? UserType {
			return user.oU_id
		}
		
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.compactMap{ CloudflareZeroTrustUser.ID(rawValue: $0) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<UserProperty>?) async throws -> CloudflareZeroTrustUser? {
		throw Err.notImplemented
//		return try await CloudflareZeroTrustUser.get(id: pID, orgID: config.orgID, connector: connector)
	}
	
	public func existingUser(fromID uID: CloudflareZeroTrustUser.ID, propertiesToFetch: Set<UserProperty>?) async throws -> CloudflareZeroTrustUser? {
		throw Err.notImplemented
//		return try await GitHubUser.get(login: uID, orgID: config.orgID, connector: connector)
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<UserProperty>?) async throws -> [CloudflareZeroTrustUser] {
		throw Err.notImplemented
//		return try await CloudflareZeroTrustUser.list(orgID: config.orgID, connector: connector)
	}
	
	public let supportsUserCreation: Bool = true
	public func createUser(_ user: CloudflareZeroTrustUser) async throws -> CloudflareZeroTrustUser {
		throw OfficeKitError.unsupportedOperation
	}
	
	public let supportsUserUpdate: Bool = false
	public func updateUser(_ user: CloudflareZeroTrustUser, propertiesToUpdate: Set<UserProperty>) async throws -> CloudflareZeroTrustUser {
		throw OfficeKitError.unsupportedOperation
	}
	
	public let supportsUserDeletion: Bool = true
	public func deleteUser(_ user: CloudflareZeroTrustUser) async throws {
//		try await user.delete(orgID: config.orgID, connector: connector)
	}
	
	public let supportsPasswordChange: Bool = false
	public func changePassword(of user: CloudflareZeroTrustUser, to newPassword: String) async throws {
		throw OfficeKitError.unsupportedOperation
	}
}
