/*
 * UserSearchController.swift
 * opendirectory_officectlproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import OfficeKit
import Vapor



final class UserSearchController {
	
	func fromPersistentId(_ req: Request) throws -> Future<View> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
	func fromUserId(_ req: Request) throws -> Future<View> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
	func fromEmail(_ req: Request) throws -> Future<View> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
	func fromExternalUser(_ req: Request) throws -> Future<View> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
	func listAllUsers(_ req: Request) throws -> Future<View> {
		let openDirectoryService = try req.make(OpenDirectoryService.self)
		
		throw NotImplementedError()
	}
	
}
