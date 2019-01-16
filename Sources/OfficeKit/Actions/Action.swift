/*
 * Action.swift
 * OfficeKit
 *
 * Created by François Lamboley on 08/01/2019.
 */

import Foundation

import AsyncOperationResult



/** */
public class OldAction<StartConfigType, ResultType> {
	
	public var isExecuting: Bool {
		return stateSyncQueue.sync{ currentState.isRunning }
	}
	
	public var result: AsyncOperationResult<ResultType>? {
		return stateSyncQueue.sync{
			switch currentState {
			case .running:                                                       return nil
			case .idleWeak(result: let r):                                       return r
			case .idleStrong(result: let r, weakeningDate: _, selfReference: _): return r
			}
		}
	}
	
	public init() {
		stateSyncQueue = DispatchQueue(label: "State Sync Queue for \(type(of: self))", attributes: [/*serial*/])
		currentState = .idleWeak(result: nil)
	}
	
	deinit {
		print("Deiniting a \(type(of: self))")
	}
	
	/** Start the action.
	
	If you try to start a running operation, the handler will be called with an
	error.
	
	Never assume the handler will be called asynchronously.
	
	When the handler is called, the state of the action will either be idleWeak
	or idleStrong (you decide with the weakeningDelay parameter).
	
	Set the weakeningDelay to `nil` to have the action being weakened directly
	with no delay, _before_ the your completion handler is called. Otherwise the
	given delay will be waited before the action is weakened. If the delay is 0
	or negative, the action will be weakened with no delay, but still
	asynchronously, and thus (probably) after the your completion handler is
	called. */
	public final func start(config: StartConfigType, weakeningDelay: TimeInterval?, handler: ((_ result: AsyncOperationResult<ResultType>) -> Void)?) {
		/* Set ourselves running if not already running, fail start otherwise. */
		let wasAlreadyRunning = stateSyncQueue.sync{ () -> Bool in
			guard !currentState.isRunning else {return true}
			currentState = .running
			return false
		}
		guard !wasAlreadyRunning else {
			handler?(.error(OperationAlreadyInProgressError()))
			return
		}
		
		/* Start the action. */
		let privateHandler = { (result: AsyncOperationResult<ResultType>) -> Void in
			self.stateSyncQueue.sync{
				if let weakeningDelay = weakeningDelay {
					let weakeningDate = Date(timeIntervalSinceNow: weakeningDelay)
					self.currentState = .idleStrong(result: result, weakeningDate: weakeningDate, selfReference: self)
				} else {
					self.currentState = .idleWeak(result: result)
				}
			}
			
			handler?(result)
		}
		do {
			try unsafeStart(config: config, handler: privateHandler)
		} catch {
			privateHandler(.error(error))
		}
	}
	
	/* **********************
      MARK: - For Subclasses
	   ********************** */
	
	/** This method is reserved for subclasses; do **not** call it directly.
	
	Start the action here. You do not need to call `super`, though you can.
	
	Call the handler when the action is done. You can call the handler
	synchronously or asynchronously. */
	public /* protected */ func unsafeStart(config: StartConfigType, handler: @escaping (_ result: AsyncOperationResult<ResultType>) -> Void) throws {
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private enum State {
		
		/** The action is not running and has no forced reference to itself. */
		case idleWeak(result: AsyncOperationResult<ResultType>?)
		/** The action is not running and has a forced reference to itself (the
		action keeps a strong reference to itself). */
		case idleStrong(result: AsyncOperationResult<ResultType>?, weakeningDate: Date, selfReference: OldAction)
		
		/** The action is running (and has a forced reference to itself). */
		case running
		
		var isRunning: Bool {
			switch self {
			case .running:               return true
			case .idleWeak, .idleStrong: return false
			}
		}
		
	}
	
	private var stateSyncQueue: DispatchQueue
	private var currentState: State
	
}
