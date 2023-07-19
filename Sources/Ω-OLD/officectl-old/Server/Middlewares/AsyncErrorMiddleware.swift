/*
 * AsyncErrorMiddleware.swift
 * officectl
 *
 * Created by François Lamboley on 2018/08/16.
 */

import Foundation

import Vapor



/**
 An ErrorMiddleware that can process errors asynchronously.
 Vapor’s error middleware is customizable with a custom handler for processing the error but it is not async.
 This does not allow (AFAIK) rendering a template properly!
 Hence this middleware. */
final class AsyncErrorMiddleware : AsyncMiddleware {
	
	init(processErrorHandler h: @escaping (_ request: Request, _ responder: AsyncResponder, _ error: Error) async throws -> Response) {
		processErrorHandler = h
	}
	
	let processErrorHandler: (_ request: Request, _ responder: AsyncResponder, _ error: Error) async throws -> Response
	
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		do {return try await next.respond(to: request)}
		catch let originalError {
			do {return try await processErrorHandler(request, next, originalError)}
			catch let processingError {
				let response = Response(status: .internalServerError, headers: [:])
				response.body = Response.Body(string: "Oops: \(originalError)\n\n\n\nOops processing oops: \(processingError)")
				response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
				return response
			}
		}
	}
	
}
