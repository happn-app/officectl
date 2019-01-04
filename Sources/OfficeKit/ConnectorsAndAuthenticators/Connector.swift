/*
 * Connector.swift
 * officectl
 *
 * Created by François Lamboley on 3/22/18.
 */

import Foundation

#if os(iOS)
	import UIKit
#endif

import AsyncOperationResult



public protocol Connector {
	
	associatedtype ScopeType
	
	/** A connector should only do one “connection” operation at a time. The
	handler operation queue given here will be used by default to serialize
	“unsafe” operations in a queue so they’re executed safely in order. */
	var connectorOperationQueue: SyncOperationQueue {get}
	
	/** `nil` if not connected, otherwise, any non-nil value */
	var currentScope: ScopeType? {get}
	
	#if os(iOS)
		func handleApplicationDidFinishLaunching(_ application: UIApplication, withLaunchOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
		func handleOpenURL(_ url: URL, inApplication application: UIApplication, withOptions options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
		func handleApplicationDidBecomeActive()
	#endif
	
	func unsafeConnect(scope: ScopeType, handler: @escaping (_ error: Error?) -> Void)
	func unsafeDisconnect(handler: @escaping (_ error: Error?) -> Void)
	
}

public extension Connector {
	
	var isConnected: Bool {
		return currentScope != nil
	}
	
	func connect(scope: ScopeType, forceIfAlreadyConnected: Bool = false, handlerQueue: DispatchQueue = .main, handler: @escaping (_ error: Error?) -> Void) {
		assert(connectorOperationQueue.maxConcurrentOperationCount == 1)
		connectorOperationQueue.addAsyncBlock{ stopOperationHandler in
			guard forceIfAlreadyConnected || !self.isConnected else {handler(nil); stopOperationHandler(); return}
			self.unsafeConnect(scope: scope, handler: { error in
				handlerQueue.async{
					handler(error)
					stopOperationHandler()
				}
			})
		}
	}
	
	func disconnect(forceIfAlreadyDisconnected: Bool = false, handlerQueue: DispatchQueue = .main, handler: @escaping (_ error: Error?) -> Void) {
		assert(connectorOperationQueue.maxConcurrentOperationCount == 1)
		connectorOperationQueue.addAsyncBlock{ stopOperationHandler in
			guard forceIfAlreadyDisconnected || self.isConnected else {handler(nil); stopOperationHandler(); return}
			self.unsafeDisconnect(handler: { error in
				handlerQueue.async{
					handler(error)
					stopOperationHandler()
				}
			})
		}
	}
	
}


class AnyConnector<ScopeType> : Connector {
	
	var currentScope: ScopeType? {
		return currentScopeHandler()
	}
	
	var connectorOperationQueue: SyncOperationQueue {
		return connectionOperationQueueHandler()
	}
	
	init<C : Connector>(base b: C) where C.ScopeType == ScopeType {
		connectionOperationQueueHandler = { b.connectorOperationQueue }
		currentScopeHandler = { b.currentScope }
		
		connectHandler = b.unsafeConnect
		disconnectHandler = b.unsafeDisconnect
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
	
	private let connectionOperationQueueHandler: () -> SyncOperationQueue
	
	private let currentScopeHandler: () -> ScopeType?
	
	private let connectHandler: (_ scope: ScopeType, _ handler: @escaping (_ error: Error?) -> Void) -> Void
	private let disconnectHandler: (_ handler: @escaping (_ error: Error?) -> Void) -> Void
	
}
