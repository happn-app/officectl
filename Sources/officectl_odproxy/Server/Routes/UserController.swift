/*
 * UserController.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 2019/07/11.
 */

import Foundation

import Vapor

import OfficeKit
import OfficeModel



final class UserController {
	
	func createUser(_ req: Request) async throws -> ApiResponse<DirectoryUserWrapper> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
		}
		let input = try req.content.decode(Request.self)
		
		let odService = req.application.openDirectoryService
		let logicalUser = try odService.logicalUser(fromWrappedUser: input.user)
		let createduser = try await odService.createUser(logicalUser, using: req.services)
		return try ApiResponse.data(odService.wrappedUser(fromUser: createduser))
	}
	
	func updateUser(_ req: Request) async throws -> ApiResponse<DirectoryUserWrapper> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
			var propertiesToUpdate: Set<String>
		}
		let input = try req.content.decode(Request.self)
		let properties = Set(input.propertiesToUpdate.map{ DirectoryUserProperty(stringLiteral: $0 )})
		
		let odService = req.application.openDirectoryService
		let logicalUser = try odService.logicalUser(fromWrappedUser: input.user)
		let updatedUser = try await odService.updateUser(logicalUser, propertiesToUpdate: properties, using: req.services)
		return try ApiResponse.data(odService.wrappedUser(fromUser: updatedUser))
	}
	
	func deleteUser(_ req: Request) async throws -> ApiResponse<String> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
		}
		let input = try req.content.decode(Request.self)
		
		let odService = req.application.openDirectoryService
		let logicalUser = try odService.logicalUser(fromWrappedUser: input.user)
		try await odService.deleteUser(logicalUser, using: req.services)
		return .data("ok")
	}
	
	func changePassword(_ req: Request) async throws -> ApiResponse<String> {
		/* The data we should have in input. */
		struct Request : Decodable {
			var userID: TaggedID
			var newPassword: String
		}
		let input = try req.content.decode(Request.self)
		
		let odService = req.application.openDirectoryService
		let user = try odService.logicalUser(fromWrappedUser: DirectoryUserWrapper(userID: input.userID))
		
		let resetPasswordAction = try odService.changePasswordAction(for: user, using: req.services)
		try await withCheckedThrowingContinuation{ continuation in
			resetPasswordAction.start(parameters: input.newPassword, weakeningMode: .alwaysInstantly, handler: { continuation.resume(with: $0) })
		}
		return ApiResponse.data("ok")
	}
	
}
