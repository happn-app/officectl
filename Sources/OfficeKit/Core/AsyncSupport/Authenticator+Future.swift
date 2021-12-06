/*
 * Authenticator+EventLoopFuture.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/11/2018.
 */

import Foundation

import NIO



public extension Authenticator {
	
	/* Does not have the exact same semantics as its non-future counterpart. If
	 * the authentication fails, with this method you won’t get any user info,
	 * but you’d still get them with the counterpart. */
	func authenticate(request: RequestType, eventLoop: EventLoop) -> EventLoopFuture<(result: RequestType, userInfo: Any?)> {
		let promise = eventLoop.makePromise(of: (result: RequestType, userInfo: Any?).self)
		authenticate(request: request, handler: { result, userInfo in
			switch result {
			case .success(let success): promise.succeed((result: success, userInfo: userInfo))
			case .failure(let error):   promise.fail(error)
			}
		})
		return promise.futureResult
	}
	
}
