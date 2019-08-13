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
	
	func createUser(_ req: Request) throws -> Future<ApiResponse<GenericDirectoryUser>> {
		struct Request : Decodable {
			var user: GenericDirectoryUser
		}
		let input = try req.content.syncDecode(Request.self)
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		let user = try openDirectoryService.logicalUser(fromGenericUser: input.user)
		return try openDirectoryService.createUser(user, on: req).map{ try ApiResponse.data(openDirectoryService.genericUser(fromUser: $0)) }
	}
	
	func updateUser(_ req: Request) throws -> Future<View> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
	func deleteUser(_ req: Request) throws -> Future<View> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
	func changePassword(_ req: Request) throws -> Future<ApiResponse<String>> {
		/* The data we should have in input. */
		struct Request : Decodable {
			var userId: TaggedId
			var newPassword: String
		}
		let input = try req.content.syncDecode(Request.self)
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		let user = try openDirectoryService.logicalUser(fromGenericUser: GenericDirectoryUser(userId: input.userId))
		
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
