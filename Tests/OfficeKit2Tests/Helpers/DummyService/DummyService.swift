/*
 * DummyService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email
import GenericJSON

import OfficeKit2
import ServiceKit



final class DummyService : UserService, GroupOfUsersService, AuthenticatorService {
	
	struct TheDummyServiceCannotBeUsed : Error {}
	
	static let providerID: String = ""
	
	typealias UserType = DummyUser
	typealias GroupOfUsersType = DummyGroupOfUsers
	typealias AuthenticationChallenge = Never
	
	static var invalidUserID: Never {fatalError()}
	static var invalidGroupOfUsersID: Never {fatalError()}
	static let supportedUserProperties: Set<UserProperty> = []
	
	let id: String
	
	init(id: String, jsonConfig: JSON) throws {
		self.id = id
	}
	
	/* ******************
	   MARK: User Service
	   ****************** */
	
	func shortDescription(fromUser user: DummyUser) -> String {
		return "<ERROR>"
	}
	
	func string(fromUserID userID: Never) -> String {
	}
	
	func userID(fromString string: String) throws -> Never {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func string(fromPersistentUserID pID: Never) -> String {
	}
	
	func persistentUserID(fromString string: String) throws -> Never {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func json(fromUser user: DummyUser) throws -> JSON {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func logicalUser(fromWrappedUser userWrapper: UserWrapper) throws -> DummyUser {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func applyHints(_ hints: [UserProperty : String?], toUser user: inout DummyUser, allowUserIDChange: Bool) -> Set<UserProperty> {
		return []
	}
	
	func existingUser(fromPersistentID pID: Never, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> DummyUser? {
	}
	
	func existingUser(fromUserID uID: Never, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> DummyUser? {
	}
	
	func listAllUsers(using services: Services) async throws -> [DummyUser] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserCreation: Bool = false
	func createUser(_ user: DummyUser, using services: Services) async throws -> DummyUser {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserUpdate: Bool = false
	func updateUser(_ user: DummyUser, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> DummyUser {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserDeletion: Bool = false
	func deleteUser(_ user: DummyUser, using services: Services) async throws {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsPasswordChange: Bool = false
	func changePassword(of user: DummyUser, to newPassword: String, using services: Services) throws {
		throw TheDummyServiceCannotBeUsed()
	}
	
	/* ****************************
	   MARK: Group of Users Service
	   **************************** */
	
	func shortDescription(fromGroupOfUsers groupOfUsers: DummyGroupOfUsers) -> String {
		return "<ERROR>"
	}
	
	func listUsers(inGroupOfUsers groupOfUsers: DummyGroupOfUsers, using services: Services) async throws -> [DummyUser] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func listGroupsOfUsers(containingUser user: DummyUser, using services: Services) async throws -> [DummyGroupOfUsers] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsEmbeddedGroupsOfUsers: Bool = false
	func listGroupsOfUsers(inGroupOfUser groupOfUser: DummyGroupOfUsers, using services: Services) async throws -> [DummyGroupOfUsers] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	/* ***************************
	   MARK: Authenticator Service
	   *************************** */
	
	func authenticate(with challenge: Never, using services: Services) async throws -> Never {
	}
	
}
