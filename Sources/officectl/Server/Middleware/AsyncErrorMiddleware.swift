/*
 * AsyncErrorMiddleware.swift
 * officectl
 *
 * Created by François Lamboley on 16/08/2018.
 */

import Foundation

import Vapor



/** An ErrorMiddleware that can process errors asynchronously. Vapor’s error
middleware is customizable with a custom handler for processing the error, but
the handler must return a non-future Response. This does not allow (AFAIK)
rendering a template properly! Hence this middleware. */
final class AsyncErrorMiddleware : Middleware {
	
	init(processErrorHandler h: @escaping (_ request: Request, _ responder: Responder, _ error: Error) throws -> EventLoopFuture<Response>) {
		processErrorHandler = h
	}
	
	let processErrorHandler: (_ request: Request, _ responder: Responder, _ error: Error) throws -> EventLoopFuture<Response>
	
	func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
		return next.respond(to: request).flatMapError{ error in
//			log.report(error: error, verbose: !environment.isRelease)
			do {
				return try self.processErrorHandler(request, next, error).flatMapError{ processingError in
					return request.eventLoop.makeSucceededFuture(self.processErrorProcessingError(request: request, originalError: error, processingError: processingError))
				}
			} catch let processingError {
				return request.eventLoop.makeSucceededFuture(self.processErrorProcessingError(request: request, originalError: error, processingError: processingError))
			}
		}
	}
	
	private func processErrorProcessingError(request: Request, originalError: Error, processingError: Error) -> Response {
		let response = Response(status: .internalServerError, headers: [:])
		response.body = Response.Body(string: "Oops: \(originalError)\n\n\n\nOops processing oops: \(processingError)")
		response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
		return response
	}
	
}
