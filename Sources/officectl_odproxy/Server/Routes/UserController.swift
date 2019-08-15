/*
 * UserController.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import OfficeKit
import Vapor



final class UserController {
	
	func createUser(_ req: Request) throws -> Future<ApiResponse<DirectoryUserWrapper>> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
		}
		let input = try req.content.syncDecode(Request.self)
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		let user = try openDirectoryService.logicalUser(fromWrappedUser: input.user)
		return try openDirectoryService.createUser(user, on: req).map{ try ApiResponse.data(openDirectoryService.wrappedUser(fromUser: $0)) }
	}
	
	func updateUser(_ req: Request) throws -> Future<ApiResponse<DirectoryUserWrapper>> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
			var propertiesToUpdate: Set<String>
		}
		let input = try req.content.syncDecode(Request.self)
		let properties = Set(input.propertiesToUpdate.map{ DirectoryUserProperty(stringLiteral: $0 )})
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		let user = try openDirectoryService.logicalUser(fromWrappedUser: input.user)
		return try openDirectoryService.updateUser(user, propertiesToUpdate: properties, on: req).map{ try ApiResponse.data(openDirectoryService.wrappedUser(fromUser: $0)) }
	}
	
	func deleteUser(_ req: Request) throws -> Future<ApiResponse<String>> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
		}
		let input = try req.content.syncDecode(Request.self)
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		let user = try openDirectoryService.logicalUser(fromWrappedUser: input.user)
		return try openDirectoryService.deleteUser(user, on: req).map{ _ in ApiResponse.data("ok") }
	}
	
	func changePassword(_ req: Request) throws -> Future<ApiResponse<String>> {
		/* The data we should have in input. */
		struct Request : Decodable {
			var userId: TaggedId
			var newPassword: String
		}
		let input = try req.content.syncDecode(Request.self)
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		let user = try openDirectoryService.logicalUser(fromWrappedUser: DirectoryUserWrapper(userId: input.userId))
		
		let ret = req.eventLoop.newPromise(ApiResponse<String>.self)
		let resetPasswordAction = try openDirectoryService.changePasswordAction(for: user, on: req) as! ResetOpenDirectoryPasswordAction
		resetPasswordAction.start(parameters: input.newPassword, weakeningMode: .alwaysInstantly, handler: { result in
			switch result {
			case .success:            ret.succeed(result: ApiResponse.data("ok"))
			case .failure(let error): ret.fail(error: error)
			}
		})
		return ret.futureResult
	}
	
}
