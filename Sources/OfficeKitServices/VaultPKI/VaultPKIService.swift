/*
 * VaultPKIService.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/26.
 */

import Foundation

import GenericJSON
import OfficeModelCore

import OfficeKit



public final class VaultPKIService : UserService {
	
	public static var providerID = "happn/vault-pki"
	
	public typealias UserType = VaultPKIUser
	
	public let id: Tag
	public let name: String
	public let config: VaultPKIServiceConfig
	
	public let authenticator: VaultPKIAuthenticator
	
	public convenience init(id: Tag, name: String, jsonConfig: JSON, workdir: URL?) throws {
		let config = try VaultPKIServiceConfig(json: jsonConfig)
		self.init(id: id, name: name, vaultPKIServiceConfig: config, workdir: workdir)
	}
	
	public init(id: Tag, name: String, vaultPKIServiceConfig: VaultPKIServiceConfig, workdir: URL?) {
		self.id = id
		self.name = name
		self.config = vaultPKIServiceConfig
		
		self.authenticator = VaultPKIAuthenticator(rootToken: config.authenticatorSettings.rootToken)
	}
	
	public func shortDescription(fromUser user: VaultPKIUser) -> String {
		return user.oU_id
	}
	
	public func string(fromUserID userID: String) -> String {
		return userID
	}
	
	public func userID(fromString string: String) throws -> String {
		return string
	}
	
	public func string(fromPersistentUserID pID: String) -> String {
		return pID
	}
	
	public func persistentUserID(fromString string: String) throws -> String {
		return string
	}
	
	public func alternateIDs(fromUserID userID: String) -> (regular: String, other: Set<String>) {
		return (regular: userID, other: [])
	}
	
	public func logicalUserID<OtherUserType>(fromUser user: OtherUserType) throws -> String where OtherUserType : OfficeKit.User {
		if let user = user as? UserType {
			return user.oU_id
		}
		
		let id = config.userIDBuilders?.lazy
			.compactMap{ $0.inferID(fromUser: user) }
			.first{ _ in true } /* Not a simple `.first` because of <https://stackoverflow.com/a/71778190> (avoid the handler(s) to be called more than once). */
		guard let id else {
			throw OfficeKitError.cannotInferUserIDFromOtherUser
		}
		return id
	}
	
	public func existingUser(fromPersistentID pID: String, propertiesToFetch: Set<OfficeKit.UserProperty>?) async throws -> VaultPKIUser? {
		struct NI : Error {}
		throw NI()
	}
	
	public func existingUser(fromID uID: String, propertiesToFetch: Set<OfficeKit.UserProperty>?) async throws -> VaultPKIUser? {
		/* AFAIK to retrieve a certificate with a given CN w/ Vault PKI, the only way is to get them all and filter. */
		let users = try await listAllUsers(includeSuspended: true, propertiesToFetch: nil)
			.filter{ $0.oU_id == uID }
		guard let user = users.first else {
			return nil
		}
		guard users.count <= 1 else {
			throw OfficeKitError.tooManyUsersFromAPI(users: users)
		}
		return user
	}
	
	public func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<OfficeKit.UserProperty>?) async throws -> [VaultPKIUser] {
		return try await ([config.issuerName] + config.additionalActiveIssuers).concurrentFlatMap{ issuerName -> [VaultPKIUser] in
			return try await VaultPKIUser.getAll(
				from: issuerName,
				includeRevoked: includeSuspended,
				vaultBaseURL: self.config.baseURL,
				vaultAuthenticator: self.authenticator
			)
		}
	}
	
	public let supportsUserCreation = true
	public func createUser(_ user: VaultPKIUser) async throws -> VaultPKIUser {
		struct NI : Error {}
		throw NI()
	}
	
	public let supportsUserUpdate = false
	public func updateUser(_ user: VaultPKIUser, propertiesToUpdate: Set<OfficeKit.UserProperty>) async throws -> VaultPKIUser {
		throw OfficeKitError.unsupportedOperation
	}
	
	public let supportsUserDeletion = true
	public func deleteUser(_ user: VaultPKIUser) async throws {
		struct NI : Error {}
		throw NI()
	}
	
	public let supportsPasswordChange = false
	public func changePassword(of user: VaultPKIUser, to newPassword: String) async throws {
		throw OfficeKitError.unsupportedOperation
	}
	
}
