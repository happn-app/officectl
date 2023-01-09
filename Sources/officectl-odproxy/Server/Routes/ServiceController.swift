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
		guard let odUser = try await odService.existingUser(fromID: input.userID, propertiesToFetch: input.propertiesToFetch, using: req.services) else {
			return .init(nil)
		}
		return try .init(OfficeKitUser(
			id: odService.string(fromUserID: odUser.oU_id),
			persistentID: odUser.oU_persistentID.flatMap(odService.string(fromPersistentUserID:)),
			underlyingUserAndService: UserAndServiceFrom(user: odUser, service: odService)!
		))
	}
	
}
