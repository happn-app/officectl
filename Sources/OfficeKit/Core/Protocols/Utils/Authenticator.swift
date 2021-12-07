/*
 * Authenticator.swift
 * officectl
 *
 * Created by François Lamboley on 29/06/2018.
 */

import Foundation



public protocol Authenticator {
	
	associatedtype RequestType
	
	func authenticate(request: RequestType, handler: @escaping (_ result: Result<RequestType, Error>, _ userInfo: Any?) -> Void)
	
}


public class AnyAuthenticator<RequestType> : Authenticator {
	
	public init<A : Authenticator>(base b: A) where A.RequestType == RequestType {
		authenticateHandler = b.authenticate
	}
	
	public func authenticate(request: RequestType, handler: @escaping (Result<RequestType, Error>, Any?) -> Void) {
		authenticateHandler(request, handler)
	}
	
	/* *************************
	   MARK: - Connector Erasure
	   ************************* */
	
	private let authenticateHandler: (_ request: RequestType, _ handler: @escaping (_ result: Result<RequestType, Error>, _ userInfo: Any?) -> Void) -> Void
	
}
