/*
 * Action.swift
 * OfficeKit
 *
 * Created by François Lamboley on 08/01/2019.
 */

import Foundation



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
	
	/** Is the operation weak? If not, the action keeps a strong reference to
	itself, thus preventing itself from being deallocated. This is useful mainly
	for subclasses that are semi-singletons.
	
	The following is true: `if isWeak then !isExecuting`. However, it is
	possible to have a non executing weak action.
	
	A weak action does not have a result. */
	public var isWeak: Bool {
		return stateSyncQueue.sync{ currentState.isWeak }
	}
	
	public let subject: SubjectType
	public var latestParameters: ParametersType?
	
	public var result: Result<ResultType, Error>? {
		return stateSyncQueue.sync{
			switch currentState {
			case .running, .idleWeak:                                             return nil
			case .idleStrong(result: let r, weakeningTimer: _, selfReference: _): return r
			}
		}
	}
	
	public init(subject s: SubjectType) {
		stateSyncQueue = DispatchQueue(label: "State Sync Queue for \(type(of: self))<\(s)>", attributes: [/*serial*/])
		currentState = .idleWeak
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
	or idleStrong (you decide with the weakeningMode parameter).
	
	- important: If you weaken the action instantly (`nil` delay, which is the
	default), the only way to retrieve the result of the action is through the
	handler given as argument of this method. A weak action always have a `nil`
	result. */
	public final func start(parameters: ParametersType, weakeningMode: WeakeningMode = WeakeningMode.defaultMode, handler: ((_ result: Result<ResultType, Error>) -> Void)?) {
		/* Set ourselves running if not already running, fail start otherwise. */
		let wasAlreadyRunning = stateSyncQueue.sync{ () -> Bool in
			guard !currentState.isRunning else {return true}
			currentState = .running(selfReference: self)
			latestParameters = parameters
			return false
		}
		guard !wasAlreadyRunning else {
			handler?(.failure(OperationAlreadyInProgressError()))
			return
		}
		
		/* Handler when the action is over. */
		let privateHandler = { (result: Result<ResultType, Error>) -> Void in
			self.stateSyncQueue.sync{
				let weaken: Bool
				let weakeningDelay: TimeInterval?
				switch (weakeningMode, result) {
				case (.never, _):                                             weaken = false; weakeningDelay = nil
				case (.onSuccess(delay: let d), .success):                    weaken = true;  weakeningDelay = d
				case (.onSuccess, .failure):                                  weaken = false; weakeningDelay = nil
				case (.onError(delay: let d), .failure):                      weaken = true;  weakeningDelay = d
				case (.onError, .success):                                    weaken = false; weakeningDelay = nil
				case (.always(successDelay: let d, errorDelay: _), .success): weaken = true;  weakeningDelay = d
				case (.always(successDelay: _, errorDelay: let d), .failure): weaken = true;  weakeningDelay = d
				}
				if weaken {
					if let delay = weakeningDelay {
						let timer = DispatchSource.makeTimerSource(flags: [], queue: self.stateSyncQueue)
						timer.setEventHandler{ self.currentState = .idleWeak }
						timer.schedule(deadline: .now() + delay, leeway: .milliseconds(250))
						/* Setting the new state will cancel the previous timer if any and resume the new one. */
						self.currentState = .idleStrong(result: result, weakeningTimer: timer, selfReference: self)
					} else {
						self.currentState = .idleWeak
					}
				} else {
					self.currentState = .idleStrong(result: result, weakeningTimer: nil, selfReference: self)
				}
			}
			
			handler?(result)
		}
		do {
			/* Start the action */
			try unsafeStart(parameters: parameters, handler: privateHandler)
		} catch {
			/* There was a sync error starting the action; let's call the end
			 * handler directly. */
			privateHandler(.failure(error))
		}
	}
	
	/** Try and weaken the opration. If it is running, throws. */
	public final func weaken() throws {
		try stateSyncQueue.sync{
			switch currentState {
			case .idleWeak:
				(/*nop*/)
				
			case .idleStrong:
				/* Setting the state cancels the weakening timer if any. */
				currentState = .idleWeak

			case .running:
				throw OperationIsNotFinishedError()
			}
		}
	}
	
	/** Clears the latestParameters variable. If the action is running, throws. */
	public final func clearLatestParameters() throws {
		try stateSyncQueue.sync{
			guard !currentState.isRunning else {throw OperationIsNotFinishedError()}
			latestParameters = nil
		}
	}
	
	/* **********************
      MARK: - For Subclasses
	   ********************** */
	
	/** This method is reserved for subclasses; do **not** call it directly.
	
	Start the action here. You do not need to call `super`, though you can.
	
	Call the handler when the action is done. You can call the handler
	synchronously or asynchronously. */
	public /* protected */ func unsafeStart(parameters: ParametersType, handler: @escaping (_ result: Result<ResultType, Error>) -> Void) throws {
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private enum State {
		
		/** The action is not running and has no forced reference to itself. */
		case idleWeak
		/** The action is not running and has a forced reference to itself (the
		action keeps a strong reference to itself). If the weakening timer is nil,
		the action will never weaken on its own. */
		case idleStrong(result: Result<ResultType, Error>, weakeningTimer: DispatchSourceTimer?, selfReference: Action)
		
		/** The action is running (and has a forced reference to itself). */
		case running(selfReference: Action)
		
		var isRunning: Bool {
			switch self {
			case .running:               return true
			case .idleWeak, .idleStrong: return false
			}
		}
		
		var isWeak: Bool {
			switch self {
			case .idleWeak:             return true
			case .running, .idleStrong: return false
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
