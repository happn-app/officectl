/*
 * AuthRequestProcessor.swift
 *
 *
 * Created by François Lamboley on 10/12/2021.
 */

import Foundation

import APIConnectionProtocols
import TaskQueue
import URLRequestOperation



public struct AuthRequestProcessor : RequestProcessor {
	
	public let authHandler: (URLRequest, @escaping (Result<URLRequest, Error>) -> Void) -> Void
	
	public init(authHandler: @escaping (URLRequest) throws -> URLRequest) {
		self.authHandler = { req, handler in handler(Result{ try authHandler(req) }) }
	}
	
	public init<Auth : Authenticator & HasTaskQueue>(_ auth: Auth) where Auth.Request == URLRequest {
		authHandler = { req, handler in Task{ handler(await Result{ try await auth.authenticate(request: req) }) } }
	}
	
	public func transform(urlRequest: URLRequest, handler: @escaping (Result<URLRequest, Error>) -> Void) {
		authHandler(urlRequest, handler)
	}
	
}
