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



public enum ConnectionMode {
	
	case addScope
	case resetScope
	
}

public enum ChangeScopeOperationType<ScopeType> {
	
	case removeAll
	
	case add(ScopeType)
	case remove(ScopeType)
	
}

public protocol Connector {
	
	associatedtype ScopeType
	
	/**
	 A connector should only do one “connection” operation at a time.
	 
	 The handler operation queue given here will be used by default to serialize “unsafe” operations in a queue so they’re executed safely in order.
	 The current scope should never be modified outside this queue. */
	var connectorOperationQueue: SyncOperationQueue {get}
	
	/**
	 `nil` if not connected, otherwise, any non-nil value.
	 
	 Thread-safety of the property is up to the implementer.
	 
	 The value of this property should not be modified outside the connector operation queue. */
	var currentScope: ScopeType? {get}
	func currentScopeContainsAll(of scope: ScopeType) -> Bool
	func currentScopeContainsAny(of scope: ScopeType) -> Bool
	
//	#if os(iOS)
//		func handleApplicationDidFinishLaunching(_ application: UIApplication, withLaunchOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
//		func handleOpenURL(_ url: URL, inApplication application: UIApplication, withOptions options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
//		func handleApplicationDidBecomeActive()
//	#else
//		func handleOpenURL(_ url: URL) -> Bool
//	#endif
	
	/**
	 The actual connection method.
	 Should not be used by clients, use the `(dis)connect…` methods instead.
	 
	 This method does not care whether the connector is connected, nor if there is already a connection in progress (hence the unsafe part of the name).
	 
	 The method should disconnect the scopes that are not needed anymore and connect the new ones.
	 Connectors that are also authenticators should take care not to authenticate a request when a change of scope is in progress.
	 A good way to do this would be to implement the actual authentication in the connector queue. */
	func unsafeChangeCurrentScope(changeType: ChangeScopeOperationType<ScopeType>, handler: @escaping (_ error: Error?) -> Void)
	
}

public extension Connector {
	
	/**
	 Uses the `currentScope` to determine if the connector is connected.
	 
	 As thread-safe as the `currentScope` property… */
	var isConnected: Bool {
		return currentScope != nil
	}
	
	/**
	 Connects the given scope.
	 
	 If the connector was already connected with the given scopes, the method is no-op, unless forceReconnect is set to `true`.
	 If some of the scopes were not connected, they will be added in the connected scopes.
	 
	 Fully thread-safe, and concurrent-connection-operation-safe
	 (if another (dis-)connection operation is in progress, the connection operation will not be launched while the previously running and queued operations are over).
	 
	 The handler will be called with the new scopes after the connection operation and an optional error. */
	func connect(scope: ScopeType, forceReconnect: Bool = false, handlerQueue: DispatchQueue = defaultDispatchQueueForFutureSupport, handler: @escaping (_ result: Result<ScopeType?, Error>) -> Void) {
		assert(connectorOperationQueue.maxConcurrentOperationCount == 1)
		connectorOperationQueue.addAsyncBlock{ stopOperationHandler in
			let connectionHandler = { (_ error: Error?) -> Void in
				handlerQueue.async{
					if let error = error {handler(.failure(error))}
					else                 {handler(.success(self.currentScope))}
					stopOperationHandler()
				}
			}
			
			guard forceReconnect || !self.currentScopeContainsAll(of: scope) else {connectionHandler(nil); return}
			self.unsafeChangeCurrentScope(changeType: .add(scope), handler: connectionHandler)
		}
	}
	
	/**
	 Disonnect the given scope.
	 
	 If the given scope is `nil` (default), fully disconnect the connector.
	 
	 If the connector was already disconnected for the given scopes, the method is no-op, unless forceDisconnect is set to `true`.
	 If some of the scopes were not present, these will be removed from the connected scopes.
	 
	 Fully thread-safe, and concurrent-connection-operation-safe
	 (if another (dis-)connection operation is in progress, the disconnection operation will not be launched while the previously running and queued operations are over).
	 
	 The handler will be called with the new scopes after the disconnection operation and an optional error. */
	func disconnect(scope: ScopeType? = nil, forceDisconnect: Bool = false, handlerQueue: DispatchQueue = defaultDispatchQueueForFutureSupport, handler: @escaping (_ result: Result<ScopeType?, Error>) -> Void) {
		assert(connectorOperationQueue.maxConcurrentOperationCount == 1)
		connectorOperationQueue.addAsyncBlock{ stopOperationHandler in
			let connectionHandler = { (_ error: Error?) -> Void in
				handlerQueue.async{
					if let error = error {handler(.failure(error))}
					else                 {handler(.success(self.currentScope))}
					stopOperationHandler()
				}
			}
			
			if let scope = scope {
				guard forceDisconnect || self.currentScopeContainsAny(of: scope) else {connectionHandler(nil); return}
				self.unsafeChangeCurrentScope(changeType: .remove(scope), handler: connectionHandler)
			} else {
				guard forceDisconnect || self.currentScope != nil else {connectionHandler(nil); return}
				self.unsafeChangeCurrentScope(changeType: .removeAll, handler: connectionHandler)
			}
		}
	}
	
}

public extension Connector where ScopeType : SetAlgebra {
	
	func currentScopeContainsAll(of scope: ScopeType) -> Bool {
		guard let currentScope = currentScope else {return false}
		return currentScope.intersection(scope) == scope
	}
	
	func currentScopeContainsAny(of scope: ScopeType) -> Bool {
		guard let currentScope = currentScope else {return false}
		return !currentScope.intersection(scope).isEmpty
	}
	
}

public extension Connector where ScopeType == Void {
	
	func currentScopeContainsAll(of scope: Void) -> Bool {
		return currentScope != nil
	}
	
	func currentScopeContainsAny(of scope: Void) -> Bool {
		return currentScope != nil
	}
	
}


class AnyConnector<ScopeType> : Connector {
	
	var connectorOperationQueue: SyncOperationQueue {
		return connectionOperationQueueHandler()
	}
	
	var currentScope: ScopeType? {
		return currentScopeHandler()
	}
	
	func currentScopeContainsAll(of scope: ScopeType) -> Bool {
		return currentScopeContainsAllOfHandler(scope)
	}
	
	func currentScopeContainsAny(of scope: ScopeType) -> Bool {
		return currentScopeContainsAnyOfHandler(scope)
	}
	
	init<C : Connector>(base b: C) where C.ScopeType == ScopeType {
		connectionOperationQueueHandler = { b.connectorOperationQueue }
		
		currentScopeHandler = { b.currentScope }
		currentScopeContainsAllOfHandler = b.currentScopeContainsAll
		currentScopeContainsAnyOfHandler = b.currentScopeContainsAny
		
		changeCurrentScopeHandler = b.unsafeChangeCurrentScope
	}
	
	func unsafeChangeCurrentScope(changeType: ChangeScopeOperationType<ScopeType>, handler: @escaping (Error?) -> Void) {
		changeCurrentScopeHandler(changeType, handler)
	}
	
	/* *************************
	   MARK: - Connector Erasure
	   ************************* */
	
	private let connectionOperationQueueHandler: () -> SyncOperationQueue
	
	private let currentScopeHandler: () -> ScopeType?
	private let currentScopeContainsAllOfHandler: (_ scope: ScopeType) -> Bool
	private let currentScopeContainsAnyOfHandler: (_ scope: ScopeType) -> Bool
	
	private let changeCurrentScopeHandler: (_ changeType: ChangeScopeOperationType<ScopeType>, _ handler: @escaping (_ error: Error?) -> Void) -> Void
	
}
