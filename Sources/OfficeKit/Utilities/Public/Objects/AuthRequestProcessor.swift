/*
 * AuthRequestProcessor.swift
 *
 *
 * Created by François Lamboley on 10/12/2021.
 */

import Foundation

import URLRequestOperation



public struct AuthRequestProcessor : RequestProcessor {
	
	public let authHandler: (URLRequest, @escaping (Result<URLRequest, Error>) -> Void) -> Void
	
	public init(authHandler: @escaping (URLRequest) throws -> URLRequest) {
		self.authHandler = { req, handler in handler(Result{ try authHandler(req) }) }
	}
	
	public init<Auth : Authenticator>(_ auth: Auth) where Auth.RequestType == URLRequest {
		authHandler = { req, handler in auth.authenticate(request: req, handler: { res, _ in handler(res) }) }
	}
	
	public func transform(urlRequest: URLRequest, handler: @escaping (Result<URLRequest, Error>) -> Void) {
		authHandler(urlRequest, handler)
	}
	
}
