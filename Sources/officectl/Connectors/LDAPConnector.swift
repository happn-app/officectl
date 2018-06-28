/*
 * LDAPConnector.swift
 * officectl
 *
 * Created by François Lamboley on 28/06/2018.
 */

import Foundation

import AsyncOperationResult
import COpenLDAP



class LDAPConnector : Connector {
	
	typealias ScopeType = Void
	typealias RequestType = Never /* The requests do not have to be authenticated: the **session** is, w/ LDAP. */
	
	var currentScope: Void?
	
	let handlerOperationQueue = HandlerOperationQueue(name: "LDAPConnector")
	
	func authenticate(request: Never, handler: @escaping (AsyncOperationResult<Never>, Any?) -> Void) {
		handler(.success(request), nil)
	}
	
	func unsafeConnect(scope: Void, handler: @escaping (Error?) -> Void) {
		handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Implemented"]))
	}
	
	func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
		handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Implemented"]))
	}
	
	func unsafeExecute(request: LDAPRequest, handler: @escaping (AsyncOperationResult<Void/*TBD*/>) -> Void) {
	}
	
}


public struct LDAPRequest {
	
	public enum Scope : ber_int_t {
		
		case base = 0
		case singleLevel = 1
		case subtree = 2
		case children = 3 /* OpenLDAP Extension */
		case `default` = -1 /* OpenLDAP Extension */
		
	}
	
	public var scope: Scope
	public var base: String
	public var searchFilter: String?
	
}
