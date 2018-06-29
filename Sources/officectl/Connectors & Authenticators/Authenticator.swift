/*
 * Authenticator.swift
 * officectl
 *
 * Created by François Lamboley on 29/06/2018.
 */

import Foundation

import AsyncOperationResult



protocol Authenticator {
	
	associatedtype RequestType
	
	func authenticate(request: RequestType, handler: @escaping (_ result: AsyncOperationResult<RequestType>, _ userInfo: Any?) -> Void)
	
}


class AnyAuthenticator<RequestType> : Authenticator {
	
	init<A : Authenticator>(base b: A) where A.RequestType == RequestType {
		authenticateHandler = b.authenticate
	}
	
	func authenticate(request: RequestType, handler: @escaping (AsyncOperationResult<RequestType>, Any?) -> Void) {
		authenticateHandler(request, handler)
	}
	
	/* *************************
	   MARK: - Connector Erasure
	   ************************* */
	
	private let authenticateHandler: (_ request: RequestType, _ handler: @escaping (_ result: AsyncOperationResult<RequestType>, _ userInfo: Any?) -> Void) -> Void
	
}
