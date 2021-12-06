/*
 * Authenticator+EventLoopFuture.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/11/2018.
 */

import Foundation

import NIO



public extension Authenticator {
	
	/* Does not have the exact same semantics as its non-future counterpart.
	 * If the authentication fails, with this method you won’t get any user info, but you’d still get them with the counterpart. */
	func authenticate(request: RequestType) async throws -> (result: RequestType, userInfo: Any?) {
		return try await withCheckedThrowingContinuation{ continuation in
			authenticate(request: request, handler: { res, userInfo in continuation.resume(with: res.map{ ($0, userInfo) }) })
		}
	}
	
}
