/*
 * UserSearchController.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import GenericJSON
import OfficeKit
import Vapor



final class UserSearchController {
	
	let openDirectoryService: OpenDirectoryService
	
	init(openDirectoryService ods: OpenDirectoryService) {
		openDirectoryService = ods
	}
	
	func fromPersistentId(_ req: Request) throws -> EventLoopFuture<ApiResponse<DirectoryUserWrapper?>> {
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
		
		return try openDirectoryService.existingUser(fromPersistentId: pId, propertiesToFetch: propertiesToFetch, on: req.eventLoop).flatMapThrowing{ user in
			/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
			return try ApiResponse.data(user.flatMap{ try self.openDirectoryService.wrappedUser(fromUser: $0) })
		}
	}
	
	func fromUserId(_ req: Request) throws -> EventLoopFuture<ApiResponse<DirectoryUserWrapper?>> {
		/* The data we should have in input. */
		struct Request : Decodable {
			var userId: TaggedId
			var propertiesToFetch: Set<String>
		}
		let input = try req.content.decode(Request.self)
		let propertiesToFetch = Set(input.propertiesToFetch.map{ DirectoryUserProperty(stringLiteral: $0) })
		let uId = try LDAPDistinguishedName(string: input.userId.id)
		
		return try openDirectoryService.existingUser(fromUserId: uId, propertiesToFetch: propertiesToFetch, on: req.eventLoop).flatMapThrowing{ user in
			/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
			return try ApiResponse.data(user.flatMap{ try self.openDirectoryService.wrappedUser(fromUser: $0) })
		}
	}
	
	func listAllUsers(_ req: Request) throws -> EventLoopFuture<ApiResponse<[DirectoryUserWrapper]>> {
		return try openDirectoryService.listAllUsers(on: req.eventLoop).flatMapThrowing{ users in
			/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
			return try ApiResponse.data(users.map{ try self.openDirectoryService.wrappedUser(fromUser: $0) })
		}
	}
	
}
