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
	
	func createUser(_ req: Request) throws -> EventLoopFuture<ApiResponse<DirectoryUserWrapper>> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
		}
		let input = try req.content.decode(Request.self)
		
		let odService = req.application.openDirectoryService
		let user = try odService.logicalUser(fromWrappedUser: input.user)
		return try odService.createUser(user, using: req.services).flatMapThrowing{ try ApiResponse.data(odService.wrappedUser(fromUser: $0)) }
	}
	
	func updateUser(_ req: Request) throws -> EventLoopFuture<ApiResponse<DirectoryUserWrapper>> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
			var propertiesToUpdate: Set<String>
		}
		let input = try req.content.decode(Request.self)
		let properties = Set(input.propertiesToUpdate.map{ DirectoryUserProperty(stringLiteral: $0 )})
		
		let odService = req.application.openDirectoryService
		let user = try odService.logicalUser(fromWrappedUser: input.user)
		return try odService.updateUser(user, propertiesToUpdate: properties, using: req.services).flatMapThrowing{ try ApiResponse.data(odService.wrappedUser(fromUser: $0)) }
	}
	
	func deleteUser(_ req: Request) throws -> EventLoopFuture<ApiResponse<String>> {
		struct Request : Decodable {
			var user: DirectoryUserWrapper
		}
		let input = try req.content.decode(Request.self)
		
		let odService = req.application.openDirectoryService
		let user = try odService.logicalUser(fromWrappedUser: input.user)
		return try odService.deleteUser(user, using: req.services).map{ _ in ApiResponse.data("ok") }
	}
	
	func changePassword(_ req: Request) throws -> EventLoopFuture<ApiResponse<String>> {
		/* The data we should have in input. */
		struct Request : Decodable {
			var userId: TaggedId
			var newPassword: String
		}
		let input = try req.content.decode(Request.self)
		
		let odService = req.application.openDirectoryService
		let user = try odService.logicalUser(fromWrappedUser: DirectoryUserWrapper(userId: input.userId))
		
		let ret = req.eventLoop.makePromise(of: ApiResponse<String>.self)
		let resetPasswordAction = try odService.changePasswordAction(for: user, using: req.services)
		resetPasswordAction.start(parameters: input.newPassword, weakeningMode: .alwaysInstantly, handler: { result in
			switch result {
			case .success:            ret.succeed(ApiResponse.data("ok"))
			case .failure(let error): ret.fail(error)
			}
		})
		return ret.futureResult
	}
	
}
