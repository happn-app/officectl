/*
 * DummyService.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email
import GenericJSON

import OfficeKit2
import ServiceKit



final class DummyService1 : UserService, GroupOfUsersService, AuthenticatorService {
	
	struct TheDummyServiceCannotBeUsed : Error {}
	
	static let providerID: String = ""
	
	typealias AuthenticatedUserType = DummyUser1
	typealias GroupOfUsersType = DummyGroupOfUsers1
	typealias AuthenticationChallenge = Never
	
	let id: String
	
	init(id: String, jsonConfig: JSON) throws {
		self.id = id
	}
	
	/* ******************
	   MARK: User Service
	   ****************** */
	
	static let supportedUserProperties: Set<UserProperty> = []
	
	func shortDescription(fromUser user: DummyUser1) -> String {
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
	
	func json(fromUser user: DummyUser1) throws -> JSON {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func logicalUser<OtherUserType>(fromUser user: OtherUserType) throws -> DummyUser1 where OtherUserType : OfficeKit2.User {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func applyHints(_ hints: [UserProperty : String?], toUser user: inout DummyUser1, allowUserIDChange: Bool) -> Set<UserProperty> {
		return []
	}
	
	func existingUser(fromPersistentID pID: Never, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> DummyUser1? {
	}
	
	func existingUser(fromID uID: Never, propertiesToFetch: Set<UserProperty>?, using services: Services) async throws -> DummyUser1? {
	}
	
	func listAllUsers(includeSuspended: Bool, propertiesToFetch: Set<OfficeKit2.UserProperty>?, using services: Services) async throws -> [DummyUser1] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserCreation: Bool = false
	func createUser(_ user: DummyUser1, using services: Services) async throws -> DummyUser1 {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserUpdate: Bool = false
	func updateUser(_ user: DummyUser1, propertiesToUpdate: Set<UserProperty>, using services: Services) async throws -> DummyUser1 {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsUserDeletion: Bool = false
	func deleteUser(_ user: DummyUser1, using services: Services) async throws {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsPasswordChange: Bool = false
	func changePassword(of user: DummyUser1, to newPassword: String, using services: Services) throws {
		throw TheDummyServiceCannotBeUsed()
	}
	
	/* ****************************
	   MARK: Group of Users Service
	   **************************** */
	
	func shortDescription(fromGroupOfUsers groupOfUsers: DummyGroupOfUsers1) -> String {
		return "<ERROR>"
	}
	
	func string(fromGroupOfUsersID groupOfUsersID: Never) -> String {
	}
	
	func groupOfUsersID(fromString string: String) throws -> Never {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func string(fromPersistentGroupOfUsersID pID: Never) -> String {
	}
	
	func persistentGroupOfUsersID(fromString string: String) throws -> Never {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func listUsers(inGroupOfUsers groupOfUsers: DummyGroupOfUsers1, using services: Services) async throws -> [DummyUser1] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	func listGroupsOfUsers(containingUser user: DummyUser1, using services: Services) async throws -> [DummyGroupOfUsers1] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	let supportsEmbeddedGroupsOfUsers: Bool = false
	func listGroupsOfUsers(inGroupOfUser groupOfUser: DummyGroupOfUsers1, using services: Services) async throws -> [DummyGroupOfUsers1] {
		throw TheDummyServiceCannotBeUsed()
	}
	
	/* ***************************
	   MARK: Authenticator Service
	   *************************** */
	
	func authenticate(with challenge: Never, using services: Services) async throws -> Never {
	}
	
}
