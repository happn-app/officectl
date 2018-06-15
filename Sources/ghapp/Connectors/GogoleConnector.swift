/*
 * GogoleConnectorHelper.swift
 * ghapp
 *
 * Created by François Lamboley on 31/05/2018.
 */

import Foundation

import AsyncOperationResult



class GogoleConnector : Connector {
	
	typealias RequestType = URLRequest
	typealias ScopeType = Set<String>
	
	let handlerOperationQueue: HandlerOperationQueue
	
	var currentScope: ScopeType?
	
	init() {
		handlerOperationQueue = HandlerOperationQueue(name: "GogoleConnector")
	}
	
	func authenticate(request: RequestType, handler: @escaping (AsyncOperationResult<RequestType>, Any?) -> Void) {
	}
	
	func unsafeConnect(scope: ScopeType, handler: @escaping (Error?) -> Void) {
	}
	
	func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
	}
	
	func unsafeGrant(scope: ScopeType, handler: @escaping (Error?) -> Void) {
	}
	
	func unsafeRevoke(scope: ScopeType, handler: @escaping (Error?) -> Void) {
	}
	
}
