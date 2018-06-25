/*
 * Connector.swift
 * ghapp
 *
 * Created by François Lamboley on 3/22/18.
 */

import Foundation

import AsyncOperationResult



public protocol Connector {
	
	associatedtype ScopeType
	associatedtype RequestType
	
	/** A connector should only do one “connection” operation at a time. The
	handler operation queue given here will be used by default to serialize
	“unsafe” operations in a queue so they’re executed safely in order. */
	var handlerOperationQueue: HandlerOperationQueue {get}
	
	/** `nil` if not connected, otherwise, any non-nil value */
	var currentScope: ScopeType? {get}
	
//	func handleApplicationDidFinishLaunching(_ application: UIApplication, withLaunchOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
//	func handleOpenURL(_ url: URL, inApplication application: UIApplication, withOptions options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
//	func handleApplicationDidBecomeActive()
	
	func authenticate(request: RequestType, handler: @escaping (_ result: AsyncOperationResult<RequestType>, _ userInfo: Any?) -> Void)
	
	func unsafeConnect(scope: ScopeType, handler: @escaping (_ error: Error?) -> Void)
	func unsafeDisconnect(handler: @escaping (_ error: Error?) -> Void)
	
}

extension Connector {
	
	var isConnected: Bool {
		return currentScope != nil
	}
	
	func connect(scope: ScopeType, handler: @escaping (_ error: Error?) -> Void) {
		handlerOperationQueue.addToQueue{ stopOperationHandler in
			self.unsafeConnect(scope: scope, handler: { error in
				DispatchQueue.main.async{
					handler(error)
					stopOperationHandler()
				}
			})
		}
	}
	
	func disconnect(handler: @escaping (_ error: Error?) -> Void) {
		handlerOperationQueue.addToQueue{ stopOperationHandler in
			self.unsafeDisconnect(handler: { error in
				DispatchQueue.main.async{
					handler(error)
					stopOperationHandler()
				}
			})
		}
	}
	
}


class AnyConnector<ScopeType, RequestType> : Connector {
	
	var currentScope: ScopeType? {
		return currentScopeHandler()
	}
	
	var handlerOperationQueue: HandlerOperationQueue {
		return handlerOperationQueueHandler()
	}
	
	init<C : Connector>(base b: C) where C.ScopeType == ScopeType, C.RequestType == RequestType {
		handlerOperationQueueHandler = { b.handlerOperationQueue }
		currentScopeHandler = { b.currentScope }
		
		authenticateHandler = b.authenticate
		
		connectHandler = b.unsafeConnect
		disconnectHandler = b.unsafeDisconnect
	}
	
	func authenticate(request: RequestType, handler: @escaping (AsyncOperationResult<RequestType>, Any?) -> Void) {
		authenticateHandler(request, handler)
	}
	
	func unsafeConnect(scope: ScopeType, handler: @escaping (Error?) -> Void) {
		connectHandler(scope, handler)
	}
	
	func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
		disconnectHandler(handler)
	}
	
	/* *************************
      MARK: - Connector Erasure
	   ************************* */
	
	private let handlerOperationQueueHandler: () -> HandlerOperationQueue
	
	private let currentScopeHandler: () -> ScopeType?
	
	private let authenticateHandler: (_ request: RequestType, _ handler: @escaping (_ result: AsyncOperationResult<RequestType>, _ userInfo: Any?) -> Void) -> Void
	
	private let connectHandler: (_ scope: ScopeType, _ handler: @escaping (_ error: Error?) -> Void) -> Void
	private let disconnectHandler: (_ handler: @escaping (_ error: Error?) -> Void) -> Void
	
}
