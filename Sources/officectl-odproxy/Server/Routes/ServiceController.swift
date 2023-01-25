/*
 * Service.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2019/07/11.
 */

import Foundation

import Vapor

import OfficeKit
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
			throw InvalidUserError()
		}
		guard let odUser = try await odService.existingUser(fromID: input.userID.id, propertiesToFetch: input.propertiesToFetch) else {
			return .init(nil)
		}
		return try .init(OfficeKitUser(odUser: odUser, odService: odService))
	}
	
	func existingUserFromPersistentID(_ req: Request) async throws -> WrappedOptional<OfficeKitUser> {
		let input = try req.content.decode(ExistingUserFromPersistentIDRequest.self)
		guard input.userPersistentID.tag == odService.id, let persistentID = UUID(uuidString: input.userPersistentID.id) else {
			throw InvalidUserError()
		}
		guard let odUser = try await odService.existingUser(fromPersistentID: persistentID, propertiesToFetch: input.propertiesToFetch) else {
			return .init(nil)
		}
		return try .init(OfficeKitUser(odUser: odUser, odService: odService))
	}
	
	func listAllUsers(_ req: Request) async throws -> [OfficeKitUser] {
		let input = try req.query.decode(ListAllUsersRequest.self)
		let users = try await odService.listAllUsers(includeSuspended: input.includeSuspended, propertiesToFetch: input.propertiesToFetch)
		return try users.map{ try OfficeKitUser(odUser: $0, odService: odService) }
	}
	
	func createUser(_ req: Request) async throws -> OfficeKitUser {
		let input = try req.content.decode(CreateUserRequest.self)
		let odUser = try input.user.odUser(odServiceID: odService.id)
		return try await OfficeKitUser(odUser: odService.createUser(odUser), odService: odService)
	}
	
	func updateUser(_ req: Request) async throws -> OfficeKitUser {
		let input = try req.content.decode(UpdateUserRequest.self)
		let odUser = try input.user.odUser(odServiceID: odService.id)
		return try await OfficeKitUser(odUser: odService.updateUser(odUser, propertiesToUpdate: input.propertiesToUpdate), odService: odService)
	}
	
	func deleteUser(_ req: Request) async throws -> Empty {
		let input = try req.content.decode(DeleteUserRequest.self)
		let odUser = try input.user.odUser(odServiceID: odService.id)
		try await odService.deleteUser(odUser)
		return Empty()
	}
	
	func changePasswordOfUser(_ req: Request) async throws -> Empty {
		let input = try req.content.decode(ChangePasswordRequest.self)
		let odUser = try input.user.odUser(odServiceID: odService.id)
		try await odService.changePassword(of: odUser, to: input.newPassword)
		return Empty()
	}
	
}
