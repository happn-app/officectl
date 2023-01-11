/*
 * Service.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2019/07/11.
 */

import Foundation

import Vapor

import OfficeKit2
import OfficeKitOffice
import OpenDirectoryOffice



final class ServiceController {
	
	let odService: OpenDirectoryService
	
	init(odService: OpenDirectoryService) {
		self.odService = odService
	}
	
	func existingUserFromID(_ req: Request) async throws -> WrappedOptional<OfficeKitUser> {
		let input = try req.content.decode(ExistingUserFromIDRequest.self)
		guard input.userID.tag == odService.id else {
			throw Abort(.badRequest, reason: "Invalid tag for user.")
		}
		guard let odUser = try await odService.existingUser(fromID: input.userID.id, propertiesToFetch: input.propertiesToFetch, using: req.services) else {
			return .init(nil)
		}
		return try .init(OfficeKitUser(odUser: odUser, odService: odService))
	}
	
	func existingUserFromPersistentID(_ req: Request) async throws -> WrappedOptional<OfficeKitUser> {
		let input = try req.content.decode(ExistingUserFromPersistentIDRequest.self)
		guard input.userPersistentID.tag == odService.id, let persistentID = UUID(uuidString: input.userPersistentID.id) else {
			throw Abort(.badRequest, reason: "Invalid tag for user.")
		}
		guard let odUser = try await odService.existingUser(fromPersistentID: persistentID, propertiesToFetch: input.propertiesToFetch, using: req.services) else {
			return .init(nil)
		}
		return try .init(OfficeKitUser(odUser: odUser, odService: odService))
	}
	
	func listAllUsers(_ req: Request) async throws -> [OfficeKitUser] {
		let input = try req.query.decode(ListAllUsersRequest.self)
		let users = try await odService.listAllUsers(includeSuspended: input.includeSuspended, propertiesToFetch: input.propertiesToFetch, using: req.services)
		return try users.map{ try OfficeKitUser(odUser: $0, odService: odService) }
	}
	
}
