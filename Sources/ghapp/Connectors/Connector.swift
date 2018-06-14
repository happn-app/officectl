/*
 * Connector.swift
 * ghapp
 *
 * Created by François Lamboley on 3/22/18.
 */

import Foundation

import AsyncOperationResult



protocol ConnectorHelper {
	
	associatedtype RequestType
	associatedtype ScopeType : SetAlgebra
	
	/** `nil` if not connected, otherwise, any non-nil value */
	var currentScope: ScopeType? {get}
	
//	func handleApplicationDidFinishLaunching(_ application: UIApplication, withLaunchOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
//	func handleOpenURL(_ url: URL, inApplication application: UIApplication, withOptions options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
//	func handleApplicationDidBecomeActive()
	
	func authenticate(request: RequestType, handler: @escaping (_ result: AsyncOperationResult<RequestType>, _ userInfo: Any?) -> Void)
	
	func connect(scope: ScopeType, handler: @escaping (_ error: Error?) -> Void)
	func refreshSession(handler: @escaping (_ error: Error?) -> Void)
	func disconnect(handler: @escaping (_ error: Error?) -> Void)
	func grant(scope: ScopeType, handler: @escaping (_ error: Error?) -> Void)
	func revoke(scope: ScopeType, handler: @escaping (_ error: Error?) -> Void)
	func checkSession(forScope scope: ScopeType, handler: @escaping (_ error: Error?) -> Void)
	
}


class Connector<ScopeType : SetAlgebra, RequestType> {
	
	init<H : ConnectorHelper>(helper h: H) where H.ScopeType == ScopeType, H.RequestType == RequestType {
		currentScopeHandler = { h.currentScope }
		
		authenticateHandler = h.authenticate
		
		connectHandler = h.connect
		refreshSessionHandler = h.refreshSession
		disconnectHandler = h.disconnect
		grantHandler = h.grant
		revokeHandler = h.revoke
		checkSessionHandler = h.checkSession
	}
	
	var isConnected: Bool {
		return currentScopeHandler() != nil
	}
	
	var currentScope: ScopeType? {
		return currentScopeHandler()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func authenticate(request: RequestType, handler: @escaping (_ result: AsyncOperationResult<RequestType>, _ userInfo: Any?) -> Void) {
		queuedActions.append{
			self.authenticateHandler(request, { result, userInfo in
				self.finishAction{ handler(result, userInfo) }
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func connect(scope: ScopeType, handler: ((_ error: Error?) -> Void)?) {
		queuedActions.append{
			self.connectHandler(scope, { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func refreshSession(handler: ((_ error: Error?) -> Void)?) {
		queuedActions.append{
			self.refreshSessionHandler({ err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func disconnect(handler: ((_ error: Error?) -> Void)?) {
		queuedActions.append{
			self.disconnectHandler({ err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func grant(scope: ScopeType, force: Bool = false, handler: ((_ error: Error?) -> Void)?) {
		queuedActions.append{
			self.grantHandler(scope, { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func revoke(scope: ScopeType, force: Bool = false, handler: ((_ error: Error?) -> Void)?) {
		queuedActions.append{
			self.revokeHandler(scope, { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func checkSession(forScope scope: ScopeType, handler: ((_ error: Error?) -> Void)?) {
		queuedActions.append{
			self.checkSessionHandler(scope, { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private var queuedActions = [() -> Void]()
	private var actionQueue = DispatchQueue(label: "A Connector Queue", qos: .utility)
	private var actionSemaphore = DispatchSemaphore(value: 1)
	
	private func startNextAction() {
		actionQueue.async{
			guard self.actionSemaphore.wait(timeout: .now()) == .success else {return}
			guard let action = self.queuedActions.popLast() else {self.actionSemaphore.signal(); return}
			action()
		}
	}
	
	private func finishAction(error: Error?, handler: ((Error?) -> Void)?) {
		if let h = handler {
			DispatchQueue.main.async{
				h(error)
				self.actionSemaphore.signal()
				self.startNextAction()
			}
		} else {
			actionSemaphore.signal()
			startNextAction()
		}
	}
	
	private func finishAction(handler: @escaping () -> Void) {
		DispatchQueue.main.async{
			handler()
			self.actionSemaphore.signal()
			self.startNextAction()
		}
	}
	
	/* *********************************
      MARK: - Connector Handler Erasure
	   ********************************* */
	
	private let currentScopeHandler: () -> ScopeType?
	
	private let authenticateHandler: (_ request: RequestType, _ handler: @escaping (_ result: AsyncOperationResult<RequestType>, _ userInfo: Any?) -> Void) -> Void
	
	private let connectHandler: (_ scope: ScopeType, _ handler: @escaping (_ error: Error?) -> Void) -> Void
	private let refreshSessionHandler: (_ handler: @escaping (_ error: Error?) -> Void) -> Void
	private let disconnectHandler: (_ handler: @escaping (_ error: Error?) -> Void) -> Void
	private let grantHandler: (_ scope: ScopeType, _ handler: @escaping (_ error: Error?) -> Void) -> Void
	private let revokeHandler: (_ scope: ScopeType, _ handler: @escaping (_ error: Error?) -> Void) -> Void
	private let checkSessionHandler: (_ scope: ScopeType, _ handler: @escaping (_ error: Error?) -> Void) -> Void
	
}
