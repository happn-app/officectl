/*
 * UserSearchController.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2019/07/11.
 */

//import Foundation
//
//import GenericJSON
//import Vapor
//
//import OfficeKit2
//
//
//
//final class UserSearchController {
//	
//	func fromPersistentID(_ req: Request) async throws -> ApiResponse<DirectoryUserWrapper?> {
//		/* The data we should have in input. */
//		struct Request : Decodable {
//			var persistentID: TaggedID
//			var propertiesToFetch: Set<String>
//		}
//		let input = try req.content.decode(Request.self)
//		let propertiesToFetch = Set(input.propertiesToFetch.map{ DirectoryUserProperty(stringLiteral: $0) })
//		guard let pID = UUID(uuidString: input.persistentID.id) else {
//			throw InvalidArgumentError(message: "Invalid persistend ID \(input.persistentID)")
//		}
//		
//		let odService = req.application.openDirectoryService
//		let user = try await odService.existingUser(fromPersistentID: pID, propertiesToFetch: propertiesToFetch, using: req.services)
//		/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
//		return try ApiResponse.data(user.flatMap{ try odService.wrappedUser(fromUser: $0) })
//	}
//	
//	func fromUserID(_ req: Request) async throws -> ApiResponse<DirectoryUserWrapper?> {
//		/* The data we should have in input. */
//		struct Request : Decodable {
//			var userID: TaggedID
//			var propertiesToFetch: Set<String>
//		}
//		let input = try req.content.decode(Request.self)
//		let propertiesToFetch = Set(input.propertiesToFetch.map{ DirectoryUserProperty(stringLiteral: $0) })
//		let uID = try LDAPDistinguishedName(string: input.userID.id)
//		
//		let odService = req.application.openDirectoryService
//		let user = try await odService.existingUser(fromUserID: uID, propertiesToFetch: propertiesToFetch, using: req.services)
//		/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
//		return try ApiResponse.data(user.flatMap{ try odService.wrappedUser(fromUser: $0) })
//	}
//	
//	func listAllUsers(_ req: Request) async throws -> ApiResponse<[DirectoryUserWrapper]> {
//		let odService = req.application.openDirectoryService
//		let users = try await odService.listAllUsers(using: req.services)
//		/* Let’s convert the OpenDirectory user to a GenericDirectoryUser */
//		return try ApiResponse.data(users.map{ try odService.wrappedUser(fromUser: $0) })
//	}
//	
//}
