/*
 * UserSearchController.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 2019/07/11.
 */

import Foundation

import GenericJSON
import OfficeKit
import Vapor



final class UserSearchController {
	
	func fromPersistentId(_ req: Request) async throws -> ApiResponse<DirectoryUserWrapper?> {
		/* The data we should have in input. */
		struct Request : Decodable {
			var persistentId: TaggedId
			var propertiesToFetch: Set<String>
		}
		let input = try req.content.decode(Request.self)
		let propertiesToFetch = Set(input.propertiesToFetch.map{ DirectoryUserProperty(stringLiteral: $0) })
		guard let pId = UUID(uuidString: input.persistentId.id) else {
			throw InvalidArgumentError(message: "Invalid persistend id \(input.persistentId)")
		}
		
		let odService = req.application.openDirectoryService
		let user = try await odService.existingUser(fromPersistentId: pId, propertiesToFetch: propertiesToFetch, using: req.services)
		/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
		return try ApiResponse.data(user.flatMap{ try odService.wrappedUser(fromUser: $0) })
	}
	
	func fromUserId(_ req: Request) async throws -> ApiResponse<DirectoryUserWrapper?> {
		/* The data we should have in input. */
		struct Request : Decodable {
			var userId: TaggedId
			var propertiesToFetch: Set<String>
		}
		let input = try req.content.decode(Request.self)
		let propertiesToFetch = Set(input.propertiesToFetch.map{ DirectoryUserProperty(stringLiteral: $0) })
		let uId = try LDAPDistinguishedName(string: input.userId.id)
		
		let odService = req.application.openDirectoryService
		let user = try await odService.existingUser(fromUserId: uId, propertiesToFetch: propertiesToFetch, using: req.services)
		/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
		return try ApiResponse.data(user.flatMap{ try odService.wrappedUser(fromUser: $0) })
	}
	
	func listAllUsers(_ req: Request) async throws -> ApiResponse<[DirectoryUserWrapper]> {
		let odService = req.application.openDirectoryService
		let users = try await odService.listAllUsers(using: req.services)
		/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
		return try ApiResponse.data(users.map{ try odService.wrappedUser(fromUser: $0) })
	}
	
}
