/*
 * AuthRequestProcessor.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/11/18.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import TaskQueue
import URLRequestOperation



public struct AuthRequestProcessor : RequestProcessor {
	
	public let authHandler: @Sendable (URLRequest, @escaping @Sendable (Result<URLRequest, Error>) -> Void) -> Void
	
	public init(authHandler: @escaping @Sendable (URLRequest) throws -> URLRequest) {
		self.authHandler = { req, handler in handler(Result{ try authHandler(req) }) }
	}
	
	public init<Auth : Authenticator & HasTaskQueue>(_ auth: Auth) where Auth.Request == URLRequest {
		authHandler = { req, handler in Task{ handler(await Result{ try await auth.authenticate(request: req) }) } }
	}
	
	public func transform(urlRequest: URLRequest, handler: @escaping @Sendable (Result<URLRequest, Error>) -> Void) {
		authHandler(urlRequest, handler)
	}
	
}
