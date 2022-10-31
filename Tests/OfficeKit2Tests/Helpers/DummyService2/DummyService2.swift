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



final class DummyService2 : UserService, GroupOfUsersService, AuthenticatorService {
	
	struct TheDummyServiceCannotBeUsed : Error {}
	
	static let providerID: String = ""
	
	typealias UserType = DummyUser2
	typealias GroupOfUsersType = DummyGroupOfUsers2
	typealias AuthenticationChallenge = Never
	
	let id: String
	
	init(id: String, jsonConfig: JSON) throws {
		self.id = id
	}
	
	/* ******************
	   MARK: User Service
	   ****************** */
	
	static let supportedUserProperties: Set<UserProperty> = []
	
	func shortDescription(fromUser user: DummyUser2) -> String {
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
	
	func json(fromUser user: DummyUser2) throws -> JSON {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func logicalUser(fromWrappedUser userWrapper: UserWrapper) throws -> DummyUser2 {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func applyHints(_ hints: [UserProperty : String?], toUser user: inout DummyUser2, allowUserIDChange: Bool) -> Set<UserProperty> {
		return []
	}
	
	func existingUser(fromPersistentID pID: Never, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> DummyUser2? {
	}
	
	func existingUser(fromUserID uID: Never, propertiesToFetch: Set<UserProperty>, using services: Services) async throws -> DummyUser2? {
	}
	
	func listAllUsers(using services: Services) async throws -> [DummyUser2] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserCreation: Bool = false
	func createUser(_ user: DummyUser2, using services: Services) async throws -> DummyUser2 {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserUpdate: Bool = false
	func updateUser(_ user: DummyUser2, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> DummyUser2 {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserDeletion: Bool = false
	func deleteUser(_ user: DummyUser2, using services: Services) async throws {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsPasswordChange: Bool = false
	func changePassword(of user: DummyUser2, to newPassword: String, using services: Services) throws {
		throw TheDummyServiceCannotBeUsed()
	}
	
	/* ****************************
	   MARK: Group of Users Service
	   **************************** */
	
	func shortDescription(fromGroupOfUsers groupOfUsers: DummyGroupOfUsers2) -> String {
		return "<ERROR>"
	}
	
	func listUsers(inGroupOfUsers groupOfUsers: DummyGroupOfUsers2, using services: Services) async throws -> [DummyUser2] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func listGroupsOfUsers(containingUser user: DummyUser2, using services: Services) async throws -> [DummyGroupOfUsers2] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsEmbeddedGroupsOfUsers: Bool = false
	func listGroupsOfUsers(inGroupOfUser groupOfUser: DummyGroupOfUsers2, using services: Services) async throws -> [DummyGroupOfUsers2] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	/* ***************************
	   MARK: Authenticator Service
	   *************************** */
	
	func authenticate(with challenge: Never, using services: Services) async throws -> Never {
	}
	
}