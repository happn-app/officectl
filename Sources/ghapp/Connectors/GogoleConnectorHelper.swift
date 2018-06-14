/*
 * GogoleConnectorHelper.swift
 * ghapp
 *
 * Created by François Lamboley on 31/05/2018.
 */

import Foundation

import AsyncOperationResult



class GogoleConnectorHelper : ConnectorHelper {
	
	typealias RequestType = URLRequest
	typealias ScopeType = Set<String>
	
	var currentScope: ScopeType?
	
	func authenticate(request: RequestType, handler: @escaping (AsyncOperationResult<RequestType>, Any?) -> Void) {
	}
	
	func connect(scope: ScopeType, handler: @escaping (Error?) -> Void) {
	}
	
	func refreshSession(handler: @escaping (Error?) -> Void) {
	}
	
	func disconnect(handler: @escaping (Error?) -> Void) {
	}
	
	func grant(scope: ScopeType, handler: @escaping (Error?) -> Void) {
	}
	
	func revoke(scope: ScopeType, handler: @escaping (Error?) -> Void) {
	}
	
	func checkSession(forScope scope: ScopeType, handler: @escaping (Error?) -> Void) {
	}
	
}
