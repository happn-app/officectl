/*
 * Action.swift
 * OfficeKit
 *
 * Created by François Lamboley on 08/01/2019.
 */

import Foundation

import AsyncOperationResult



/** The weakening mode for an Action. When the `TimeInterval` is `nil`, the
action is weakened before the handler is called, otherwise, whatever the time
interval value, the weakening is done asynchronously after the handler is
called, on an internal queue. */
public enum WeakeningMode {
	
	case never
	case onError(delay: TimeInterval?)
	case onSuccess(delay: TimeInterval?)
	case always(successDelay: TimeInterval?, errorDelay: TimeInterval?)
	
	public static let alwaysInstantly = WeakeningMode.always(successDelay: nil, errorDelay: nil)
	
	/** Customizable default, used by Action, when running it. */
	public static var defaultMode = WeakeningMode.alwaysInstantly
	
}

/** An Action is basically an Operation that can be run more than once. It does
not have all the conveniences the Operations do (dependencies, queues, etc.). An
Action is not in itself a SemiSingleton, however it is more or less expected
that subclasses are. In particular, an Action has an option to keep a strong
reference to itself, and automatically clear it at a given point in time. */
public class Action<SubjectType, ParametersType, ResultType> {
	
	public var isExecuting: Bool {
		return stateSyncQueue.sync{ currentState.isRunning }
	}
	
	public let subject: SubjectType
	public var latestParameters: ParametersType?
	
	public var result: AsyncOperationResult<ResultType>? {
		return stateSyncQueue.sync{
			switch currentState {
			case .running:                                                        return nil
			case .idleWeak(result: let r):                                        return r
			case .idleStrong(result: let r, weakeningTimer: _, selfReference: _): return r
			}
		}
	}
	
	public init(subject s: SubjectType) {
		stateSyncQueue = DispatchQueue(label: "State Sync Queue for \(type(of: self))<\(s)>", attributes: [/*serial*/])
		currentState = .idleWeak(result: nil)
		subject = s
	}
	
	deinit {
		print("Deiniting a \(type(of: self))")
	}
	
	/** Start the action.
	
	If you try to start a running operation, the handler will be called with an
	error.
	
	Never assume the handler will be called asynchronously.
	
	When the handler is called, the state of the action will either be idleWeak
	or idleStrong (you decide with the weakeningMode parameter). */
	public final func start(parameters: ParametersType, weakeningMode: WeakeningMode = WeakeningMode.defaultMode, handler: ((_ result: AsyncOperationResult<ResultType>) -> Void)?) {
		/* Set ourselves running if not already running, fail start otherwise. */
		let wasAlreadyRunning = stateSyncQueue.sync{ () -> Bool in
			guard !currentState.isRunning else {return true}
			currentState = .running(selfReference: self)
			return false
		}
		guard !wasAlreadyRunning else {
			handler?(.error(OperationAlreadyInProgressError()))
			return
		}
		
		/* Handler when the action is over. */
		let privateHandler = { (result: AsyncOperationResult<ResultType>) -> Void in
			self.stateSyncQueue.sync{
				let weaken: Bool
				let weakeningDelay: TimeInterval?
				switch (weakeningMode, result.isSuccessful) {
				case (.never, _):                                          weaken = false; weakeningDelay = nil
				case (.onSuccess(delay: let d), true):                     weaken = true;  weakeningDelay = d
				case (.onSuccess, false):                                  weaken = false; weakeningDelay = nil
				case (.onError(delay: let d), false):                      weaken = true;  weakeningDelay = d
				case (.onError, true):                                     weaken = false; weakeningDelay = nil
				case (.always(successDelay: let d, errorDelay: _), true):  weaken = true;  weakeningDelay = d
				case (.always(successDelay: _, errorDelay: let d), false): weaken = true;  weakeningDelay = d
				}
				if weaken {
					if let delay = weakeningDelay {
						let timer = DispatchSource.makeTimerSource(flags: [], queue: self.stateSyncQueue)
						timer.setEventHandler{ self.currentState = .idleWeak(result: result) }
						timer.schedule(deadline: .now() + delay, leeway: .milliseconds(250))
						/* Setting the new state will cancel the previous timer if any and resume the new one. */
						self.currentState = .idleStrong(result: result, weakeningTimer: timer, selfReference: self)
					} else {
						self.currentState = .idleWeak(result: result)
					}
				} else {
					self.currentState = .idleStrong(result: result, weakeningTimer: nil, selfReference: self)
				}
			}
			
			handler?(result)
		}
		do {
			/* Start the action */
			latestParameters = parameters
			try unsafeStart(parameters: parameters, handler: privateHandler)
		} catch {
			/* There was a sync error starting the action; let's call the end
			 * handler directly. */
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
	public /* protected */ func unsafeStart(parameters: ParametersType, handler: @escaping (_ result: AsyncOperationResult<ResultType>) -> Void) throws {
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private enum State {
		
		/** The action is not running and has no forced reference to itself. */
		case idleWeak(result: AsyncOperationResult<ResultType>?)
		/** The action is not running and has a forced reference to itself (the
		action keeps a strong reference to itself). If the weakening timer is nil,
		the action will never weaken on its own. */
		case idleStrong(result: AsyncOperationResult<ResultType>?, weakeningTimer: DispatchSourceTimer?, selfReference: Action)
		
		/** The action is running (and has a forced reference to itself). */
		case running(selfReference: Action)
		
		var isRunning: Bool {
			switch self {
			case .running:               return true
			case .idleWeak, .idleStrong: return false
			}
		}
		
		var timer: DispatchSourceTimer? {
			switch self {
			case .running, .idleWeak:      return nil
			case .idleStrong(_, let t, _): return t
			}
		}
		
	}
	
	private var stateSyncQueue: DispatchQueue
	private var currentState: State {
		willSet {currentState.timer?.cancel()}
		didSet  {currentState.timer?.resume()}
	}
	
}
