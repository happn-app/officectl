/*
 * LoggedInUser.swift
 * officectl
 *
 * Created by François Lamboley on 17/04/2020.
 */

import Foundation

import OfficeKit
import Vapor



struct LoggedInUser : Authenticatable {
	
	static func guardAdminMiddleware() -> Middleware {
		return IsAdminAuthMiddleware()
	}
	
	var userId: AnyDSUIdPair
	var isAdmin: Bool
	
	func representsSameUserAs(dsuIdPair: AnyDSUIdPair, request: Request) throws -> Bool {
		let sProvider = request.application.officeKitServiceProvider
		let authService = try sProvider.getDirectoryAuthenticatorService()
		return try userId.taggedId == dsuIdPair.dsuPair().hop(to: authService).taggedId
	}
	
	private struct IsAdminAuthMiddleware : Middleware {
		
		func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
			guard let u = req.auth.get(LoggedInUser.self), u.isAdmin else {
				return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "This endpoint is reserved to admins"))
			}
			return next.respond(to: req)
		}
		
	}
	
}
