/*
 * ListUsersController.swift
 * officectl
 *
 * Created by François Lamboley on 16/06/2021.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import SemiSingleton
import Vapor

import OfficeKit



final class ListUsersController {
	
	func showUsersList(_ req: Request) throws -> EventLoopFuture<String> {
		let app = req.application
		let serviceProvider = app.officeKitServiceProvider
		let service: GoogleService = try serviceProvider.getUserDirectoryService(id: nil)
		
		return try service.listAllUsers(using: app.services)
			.map{ $0.map{ service.shortDescription(fromUser: $0) } }
			.map{ users in
				var i = 1
				var res = ""
				for user in users.filter({ $0.hasSuffix("@happn.fr") }) {
					res += user + ","
					if i == 69 {res += "\n\n"; i = 0}
					i += 1
				}
				return res
			}
	}
	
}
