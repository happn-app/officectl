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
		guard input.userID.tag == odService.id else {
			throw Abort(.badRequest, reason: "Invalid tag for user.")
		}
		guard let odUser = try await odService.existingUser(fromID: input.userID.id, propertiesToFetch: input.propertiesToFetch, using: req.services) else {
			return .init(nil)
		}
		return try .init(OfficeKitUser(
			underlyingUser: UserAndServiceFrom(user: odUser, service: odService)!,
			nonStandardProperties: [:],
			opaqueUserInfo: JSONEncoder().encode(odUser.properties)
		))
	}
	
}
