/*
 * HTTPStatusToErrorMiddleware.swift
 * officectl
 *
 * Created by François Lamboley on 17/08/2018.
 */

import Foundation

import Vapor



final class HTTPStatusToErrorMiddleware : Middleware, ServiceType {
	
	struct HTTPStatusError : Error, CustomStringConvertible {
		
		let originalResponse: HTTPResponse
		
		var description: String {
			return "HTTPStatusError(\(originalResponse.status))"
		}
		
	}
	
	static func makeService(for worker: Container) throws -> HTTPStatusToErrorMiddleware {
		return HTTPStatusToErrorMiddleware()
	}
	
	let erroredStatusCodes: Set<UInt>
	
	init(erroredStatusCodes c: Set<UInt> = Set(400..<600)) {
		erroredStatusCodes = c
	}
	
	func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
		let futureResponse: Future<Response>
		do    {futureResponse = try next.respond(to: request)}
		catch {futureResponse = request.eventLoop.newFailedFuture(error: error)}
		
		return futureResponse.thenThrowing{ r in
			if self.erroredStatusCodes.contains(r.http.status.code) {
				throw HTTPStatusError(originalResponse: r.http)
			}
			return r
		}
	}

}
