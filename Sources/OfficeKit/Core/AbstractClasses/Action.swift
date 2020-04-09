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
open class Action<SubjectType, ParametersType, ResultType> : AnyAction {
	
	public final var isExecuting: Bool {
		return stateSyncQueue.sync{ currentState.isRunning }
	}
	
	/**
	Is the operation weak? If not, the action keeps a strong reference to itself,
	thus preventing itself from being deallocated. This is useful mainly for
	subclasses that are semi-singletons.
	
	The following is true: `if isWeak then !isExecuting`. However, it is
	possible to have a non executing weak action.
	
	A weak action does not have a result. */
	public final var isWeak: Bool {
		return stateSyncQueue.sync{ currentState.isWeak }
	}
	
	public final let subject: SubjectType
	public final var latestParameters: ParametersType?
	
	public final var result: Result<ResultType, Error>? {
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
		OfficeKitConfig.logger?.debug("Deiniting a \(type(of: self))")
	}
	
	/**
	Start the action.
	
	If you try to start a running action, the shouldJoinRunningAction will be
	called with the parameters w/ which the action is currently running. You can
	decide whether to join the action and get your handler called when the
	operation is over, but the parameters won’t change.
	You can for instance join the action to relaunch it w/ your parameters in the
	end handler.
	If you decide _not_ to join the action, your end handler will be called w/ an
	`OperationAlreadyInProgressError` error.
	
	Never assume the end handler will be called asynchronously.
	
	When the end handler is called, the state of the action will either be
	idleWeak or idleStrong (you decide with the weakeningMode parameter).
	
	- important: If you weaken the action instantly (`nil` delay, which is the
	default), the only way to retrieve the result of the action is through the
	handler given as argument of this method. A weak action always have a `nil`
	result. */
	public final func start(
		parameters: ParametersType,
		weakeningMode: WeakeningMode = WeakeningMode.defaultMode,
		shouldJoinRunningAction: (_ currentParameters: ParametersType) -> Bool = { _ in false },
		shouldRetrievePreviousRun: (_ previousParameters: ParametersType?, _ runWasSuccessful: Bool) -> Bool = { _, _ in false },
		handler: ((_ result: Result<ResultType, Error>) -> Void)?
	) {
		/* Pre-checks before running the action */
		let (shouldLaunch, handlerCallArgument) = stateSyncQueue.sync{ () -> (Bool, Result<ResultType, Error>?) in
			guard !currentState.isRunning else {
				/* If we’re running, let’s check whether the client wants to join
				 * the currently running action and be called when we’re done. */
				if shouldJoinRunningAction(self.latestParameters!) {
					if let h = handler {endHandlers.append(h)}
					else               {OfficeKitConfig.logger?.warning("Asked to join a running action of type \(type(of: self)) for subject \(self.subject) but no handler given…")}
					return (false, nil)
				} else {
					return (false, .failure(OperationAlreadyInProgressError()))
				}
			}
			
			if case .idleStrong(let r, _, _) = currentState {
				/* If we’re not running but have a result from a previous run, let’s
				 * see if the client wants to retrieve the result directly. */
				guard !shouldRetrievePreviousRun(latestParameters, r.isSuccessful) else {
					return (false, r)
				}
			}
			
			assert(endHandlers.isEmpty)
			if let h = handler {endHandlers.append(h)}
			
			currentState = .running(selfReference: self)
			latestParameters = parameters
			return (true, nil)
		}
		if let r = handlerCallArgument {handler?(r)}
		guard shouldLaunch else {return}
		
		/* Handler when the action is over. */
		let privateHandler = { (result: Result<ResultType, Error>) -> Void in
			let savedEndHandlers = self.stateSyncQueue.sync{ () -> Array<(_ result: Result<ResultType, Error>) -> Void> in
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
				
				let savedEndHandlers = self.endHandlers
				self.endHandlers = []
				
				return savedEndHandlers
			}
			
			savedEndHandlers.forEach{ $0(result) }
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
	
	/**
	This method is reserved for subclasses; do **not** call it directly.
	
	Start the action here. You do not need to call `super`, though you can.
	
	Call the handler when the action is done. You can call the handler
	synchronously or asynchronously. */
	open /* protected */ func unsafeStart(parameters: ParametersType, handler: @escaping (_ result: Result<ResultType, Error>) -> Void) throws {
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
	/* **Must** be changed on the stateSyncQueue */
	private var endHandlers = Array<(_ result: Result<ResultType, Error>) -> Void>()
	
}
