/*
 * Connector.swift
 * ghapp
 *
 * Created by François Lamboley on 3/22/18.
 */

import Foundation

import AsyncOperationResult



protocol ConnectorScope : SetAlgebra {}

protocol ConnectorHelper {
	
	associatedtype RequestType
	associatedtype Scope : ConnectorScope
	
	/** `nil` if not connected, otherwise, any non-nil value */
	var currentScope: Scope? {get}
	
//	func handleApplicationDidFinishLaunching(_ application: UIApplication, withLaunchOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
//	func handleOpenURL(_ url: URL, inApplication application: UIApplication, withOptions options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool
//	func handleApplicationDidBecomeActive()
	
	func authenticate(request: RequestType, handler: @escaping (_ result: AsyncOperationResult<RequestType>, _ userInfo: Any?) -> Void)
	
	func connect(scope: Scope, handler: @escaping (_ error: Error?) -> Void)
	func refreshSession(handler: @escaping (_ error: Error?) -> Void)
	func disconnect(handler: @escaping (_ error: Error?) -> Void)
	func grant(scope: Scope, handler: @escaping (_ error: Error?) -> Void)
	func revoke(scope: Scope, handler: @escaping (_ error: Error?) -> Void)
	func checkSession(forScope scope: Scope, handler: @escaping (_ error: Error?) -> Void)
	
}


class Connector<Helper : ConnectorHelper> {
	
	typealias Scope = Helper.Scope
	typealias RequestType = Helper.RequestType
	
	let helper: Helper
	
	init(helper h: Helper) {
		helper = h
	}
	
	var isConnected: Bool {
		return helper.currentScope != nil
	}
	
	var currentScope: Scope? {
		return helper.currentScope
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func connect(scope: Scope, handler: ((_ error: Error?) -> Void)?) {
		assert(Thread.isMainThread)
		
		queuedActions.append{
			self.helper.connect(scope: scope, handler: { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func refreshSession(handler: ((_ error: Error?) -> Void)?) {
		assert(Thread.isMainThread)
		
		queuedActions.append{
			self.helper.refreshSession(handler: { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func disconnect(handler: ((_ error: Error?) -> Void)?) {
		assert(Thread.isMainThread)
		
		queuedActions.append{
			self.helper.disconnect(handler: { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func grant(scope: Scope, force: Bool = false, handler: ((_ error: Error?) -> Void)?) {
		assert(Thread.isMainThread)
		
		queuedActions.append{
			self.helper.grant(scope: scope, handler: { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func revoke(scope: Scope, force: Bool = false, handler: ((_ error: Error?) -> Void)?) {
		assert(Thread.isMainThread)
		
		queuedActions.append{
			self.helper.revoke(scope: scope, handler: { err in
				self.finishAction(error: err, handler: handler)
			})
		}
		startNextAction()
	}
	
	/** If there is already an action in progress, the action will be delayed
	until the current (and all other currently queued) action(s) are finished.
	
	The handler is always called on the main thread. */
	func checkSession(forScope scope: Scope, handler: ((_ error: Error?) -> Void)?) {
		assert(Thread.isMainThread)
		
		queuedActions.append{
			self.helper.checkSession(forScope: scope, handler: { err in
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
	
}
