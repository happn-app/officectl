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
	
	func changePassword(_ req: Request) throws -> Future<View> {
		let request = try req.content.syncDecode(Request.self)
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
		
		/* The data we should have in input. */
		struct Request : Decodable {
			var userId: JSON
			var newPassword: String
		}
	}
	
}
