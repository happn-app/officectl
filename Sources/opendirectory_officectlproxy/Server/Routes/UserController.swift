/*
 * UserController.swift
 * opendirectory_officectlproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import GenericJSON
import OfficeKit
import Vapor



final class UserController {
	
	func createUser(_ req: Request) throws -> Future<View> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
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
			var userId: JSON
			var newPassword: String
		}
		
		let request = try req.content.syncDecode(Request.self)
		guard let userId = GenericDirectoryUserId(rawValue: request.userId) else {
			throw InvalidArgumentError(message: "Cannot retrieve the user id from the request")
		}
		
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		guard let user = try openDirectoryService.logicalUser(fromGenericUserId: userId, on: req) else {
			throw InvalidArgumentError(message: "Cannot retrieve a user from the user id in the request")
		}
		
		let ret = req.eventLoop.newPromise(ApiResponse<String>.self)
		let resetPasswordAction = try openDirectoryService.changePasswordAction(for: user, on: req) as! ResetOpenDirectoryPasswordAction
		resetPasswordAction.start(parameters: request.newPassword, weakeningMode: .alwaysInstantly, handler: { result in
			switch result {
			case .success:            ret.succeed(result: ApiResponse.data("ok"))
			case .failure(let error): ret.fail(error: error)
			}
		})
		return ret.futureResult
	}
	
}
