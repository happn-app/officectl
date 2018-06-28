/*
 * LDAPConnector.swift
 * officectl
 *
 * Created by François Lamboley on 28/06/2018.
 */

import Foundation

import AsyncOperationResult
import COpenLDAP
//import OpenDirectory



class LDAPConnector : Connector {
	
	typealias ScopeType = Void
	typealias RequestType = String
	
	var currentScope: Void?
	
	let handlerOperationQueue = HandlerOperationQueue(name: "LDAPConnector")
	
	func authenticate(request: String, handler: @escaping (AsyncOperationResult<String>, Any?) -> Void) {
		handler(AORError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Implemented"]), nil)
	}
	
	func unsafeConnect(scope: Void, handler: @escaping (Error?) -> Void) {
//		let serverName = "vip-ldap.happn.io"
//		let session = ODSession.default()
//		let node = try! ODNode(session: session, name: "/LDAPv3/" + serverName)
//		let query = try! ODQuery(node: node, forRecordTypes: ["uid"], attribute: "mail", matchType: ODMatchType(kODMatchAny), queryValues: "francois.lamboley@happn.fr", returnAttributes: nil, maximumResults: 3)
//		print(try! query.resultsAllowingPartial(false))
		handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Implemented"]))
	}
	
	func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
		handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Implemented"]))
	}
	
}
