/*
 * ExternalServiceAuthenticator.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation



public class ExternalServiceAuthenticator : Authenticator {
	
	public typealias RequestType = URLRequest
	
	public var jwtSecret: Data
	
	public init(jwtSecret secret: Data) {
		jwtSecret = secret
	}
	
	public func authenticate(request: URLRequest, handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) {
		var request = request
		#warning("TODO")
		request.addValue("TODO", forHTTPHeaderField: "Officectl-Signature")
		handler(.success(request), nil)
	}
	
}
