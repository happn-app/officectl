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
final class AsyncErrorMiddleware : Middleware, ServiceType {
	
	static func makeService(for worker: Container) throws -> AsyncErrorMiddleware {
		return AsyncErrorMiddleware{ request, error in
			/* Simple default error handling. */
			let response = request.response(http: HTTPResponse(status: .internalServerError, headers: [:]))
			response.http.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
			response.http.body = HTTPBody(string: "error: " + error.localizedDescription)
			return request.future(response)
		}
	}
	
	init(processErrorHandler h: @escaping (_ request: Request, _ error: Error) throws -> EventLoopFuture<Response>) {
		processErrorHandler = h
	}
	
	let processErrorHandler: (_ request: Request, _ error: Error) throws -> EventLoopFuture<Response>
	
	func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
		let futureResponse: Future<Response>
		do    {futureResponse = try next.respond(to: request)}
		catch {futureResponse = request.eventLoop.newFailedFuture(error: error)}
		
		return futureResponse.thenIfError{ error in
//			log.report(error: error, verbose: !environment.isRelease)
			do {
				return try self.processErrorHandler(request, error).thenIfError{ processingError in
					return request.future(self.processErrorProcessingError(request: request, originalError: error, processingError: processingError))
				}
			} catch let processingError {
				return request.future(self.processErrorProcessingError(request: request, originalError: error, processingError: processingError))
			}
		}
	}
	
	private func processErrorProcessingError(request: Request, originalError: Error, processingError: Error) -> Response {
		let response = request.response(http: HTTPResponse(status: .internalServerError, headers: [:]))
		response.http.body = HTTPBody(string: "Oops: \(originalError)\n\n\n\nOops processing oops: \(processingError)")
		response.http.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
		return response
	}
	
}
