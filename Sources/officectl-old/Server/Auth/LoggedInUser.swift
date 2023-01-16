/*
 * LoggedInUser.swift
 * officectl
 *
 * Created by François Lamboley on 2020/04/17.
 */

import Foundation

import OfficeKit
import Vapor

import OfficeModel



struct LoggedInUser : Authenticatable, SessionAuthenticatable {
	
	typealias SessionID = TaggedID
	
	/** A simple guard auth middleware for admin users */
	static func guardAdminMiddleware() -> AsyncMiddleware {
		struct IsAdminAuthMiddleware : AsyncMiddleware {
			func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
				guard let u = req.auth.get(LoggedInUser.self), u.scopes.contains(.admin) else {
					throw Abort(.forbidden, reason: "This endpoint is reserved to admins")
				}
				return try await next.respond(to: req)
			}
		}
		return IsAdminAuthMiddleware()
	}
	
	/**
	 A login guard middleware a little more permissive than the strict login guard.
	 It will allow a non-authed connexion as long as a previous authed connexion has been logged by
	 this middleware from the same IP address less than `leeway` seconds ago.
	 Set the leeway to 0 or less to get a standard guard middleware (but that still log authed connexions so another Xcode guard middleware can use them).
	 
	 Why?
	 Because iOS does not retransmit the cookies set in the browser when downloading the manifest for installing an IPA,
	 or when downloading the IPA (these requests are done by another process).
	 AFAICT the process that downloads the IPA sends no other identifying information than the IP. */
	static func xcodeGuardMiddleware(leeway: TimeInterval) -> AsyncMiddleware {
		struct XcodeGuardAuthMiddleware : AsyncMiddleware {
			var leeway: TimeInterval
			func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
				guard req.auth.has(LoggedInUser.self) else {
					/* Let’s see if we have a leeway and the IP of our current req. */
					guard leeway > 0, let currentIP = req.remoteAddress?.ipAddress else {
						throw Abort(.unauthorized)
					}
					/* We do!
					 * Has there been an auth’d connexion less than leeway ago on the same IP than the current request? */
					let lock = req.application.locks.lock(for: XcodeGuardMiddlewareConnectionsLock.self)
					let hadAuth = lock.withLock{ () -> Bool in
						let storage = req.application.officectlStorage.xcodeGuardMiddlewareConnections
						guard let latestDate = storage[currentIP] else {
							return false
						}
						guard latestDate > Date() - leeway else {
							return false
						}
						return true
					}
					guard hadAuth else {
						throw Abort(.unauthorized)
					}
					/* We do **not** register the successful auth (because the request was not actually auth’d…) */
					return try await next.respond(to: req)
				}
				/* Let’s register the successfully auth’d request if possible */
				if let ip = req.remoteAddress?.ipAddress {
					let lock = req.application.locks.lock(for: XcodeGuardMiddlewareConnectionsLock.self)
					lock.withLockVoid{
						req.application.officectlStorage.xcodeGuardMiddlewareConnections[ip] = Date()
					}
				}
				return try await next.respond(to: req)
			}
		}
		return XcodeGuardAuthMiddleware(leeway: leeway)
	}
	
	var user: AnyDSUPair
	var scopes: Set<AuthScope>
	
	var sessionID: TaggedID {
		return user.taggedID
	}
	
	func representsSameUserAs(dsuIDPair: AnyDSUIDPair, request: Request) throws -> Bool {
		let sProvider = request.application.officeKitServiceProvider
		let authService = try sProvider.getDirectoryAuthenticatorService()
		return try user.taggedID == dsuIDPair.dsuPair().hop(to: authService).taggedID
	}
	
}


private struct XcodeGuardMiddlewareConnectionsLock : LockKey {}