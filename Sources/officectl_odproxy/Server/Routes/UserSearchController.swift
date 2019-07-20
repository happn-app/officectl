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
	
	func fromPersistentId(_ req: Request) throws -> Future<ApiResponse<GenericDirectoryUser?>> {
		/* The data we should have in input. */
		struct Request : Decodable {
			var persistentId: JSON
			var propertiesToFetch: Set<String>
		}
		let input = try req.content.syncDecode(Request.self)
		let propertiesToFetch = Set(input.propertiesToFetch.map{ DirectoryUserProperty(stringLiteral: $0) })
		guard let pId = input.persistentId.stringValue.flatMap({ UUID($0) }) else {
			throw InvalidArgumentError(message: "Invalid persistend id \(input.persistentId)")
		}
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		return try openDirectoryService.existingUser(fromPersistentId: pId, propertiesToFetch: propertiesToFetch, on: req).map{ user in
			/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
			return try ApiResponse.data(user.flatMap{ try GenericDirectoryUser(recordWrapper: $0, odService: openDirectoryService) })
		}
	}
	
	func fromUserId(_ req: Request) throws -> Future<ApiResponse<GenericDirectoryUser?>> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
	func fromEmail(_ req: Request) throws -> Future<ApiResponse<GenericDirectoryUser?>> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
	func fromExternalUser(_ req: Request) throws -> Future<ApiResponse<GenericDirectoryUser?>> {
		struct Request : Decodable {
			var serviceId: String
			var userId: String
			var user: JSON
			var propertiesToFetch: Set<String>
		}
		let input = try req.content.syncDecode(Request.self)
		let propertiesToFetch = Set(input.propertiesToFetch.map{ DirectoryUserProperty(stringLiteral: $0) })
		let userId = GenericDirectoryUserId.proxy(serviceId: input.serviceId, userId: input.userId, user: input.user)
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		return try openDirectoryService.existingUser(fromJSONUserId: userId.rawValue, propertiesToFetch: propertiesToFetch, on: req).map{ user in
			/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
			return try ApiResponse.data(user.flatMap{ try GenericDirectoryUser(recordWrapper: $0, odService: openDirectoryService) })
		}
	}
	
	func listAllUsers(_ req: Request) throws -> Future<ApiResponse<[GenericDirectoryUser]>> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		return try openDirectoryService.listAllUsers(on: req).map{ users in
			/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
			return try ApiResponse.data(users.map{ try GenericDirectoryUser(recordWrapper: $0, odService: openDirectoryService) })
		}
	}
	
}
