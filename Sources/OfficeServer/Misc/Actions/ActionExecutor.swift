/*
 * ActionExecutor.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation

import SemiSingleton



extension ActionExecutor : SemiSingleton where Subject : Hashable {}
public final class ActionExecutor<Action : ActionProtocol> : @unchecked Sendable {

	public typealias Subject    = Action.Subject
	public typealias Parameters = Action.Parameters
	public typealias Results    = Action.Results
	
	public typealias SemiSingletonKey = Subject
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public final var isExecuting: Bool {
		return stateSyncQueue.sync{ currentState.isRunning }
	}
	
	/**
	 Is the operation weak?
	 If not, the action keeps a strong reference to itself, thus preventing itself from being deallocated.
	 This is useful mainly for subclasses that are semi-singletons.
	 
	 The following is true: `if isWeak then !isExecuting`.
	 However, it is possible to have a non executing weak action.
	 
	 A weak action does not have a result. */
	public final var isWeak: Bool {
		return stateSyncQueue.sync{ currentState.isWeak }
	}
	
	public final let action: Action
	public final var latestParameters: Parameters?
	
	public final var result: Result<Results, Error>? {
		return stateSyncQueue.sync{ currentState.result }
	}
	
	public init(subject: Subject) {
		self.currentState = .idleWeak
		self.action = Action(subject: subject)
	}
	
	public convenience init(key: Subject, additionalInfo: Void, store: SemiSingletonStore) {
		self.init(subject: key)
	}
	
	deinit {
//		OfficeKitConfig.logger?.debug("Deiniting a \(type(of: self))")
	}
	
	/**
	 Start the action.
	 
	 If you try to start a running action, the `shouldJoinRunningAction` handler will be called with the parameters w/ which the action is currently running.
	 You can decide whether to join the action and get your handler called when the action is over, but the parameters won’t change.
	 You can for instance join the action to relaunch it w/ your parameters in your end handler.
	 If you decide _not_ to join the action (the default), your end handler will be called w/ an `ApiError.actionIsAlreadyRunning` error.
	 
	 If you try to start an action that has a result (the action is finished & strong),
	  the `shouldRetrievePreviousRun` handler will be called, with the previous known parameters w/ which the action was run
	  (might be `nil` because the client can clear the latest parameters to free up some memory),
	  and a boolean set to whether the run was successful (`result.isSuccessful`).
	 
	 If you decide _not_ to retrieve the previous results, the action will be run again normally.
	 Otherwise your end handler will be called w/ the current result of the action.
	 
	 This is the preferred method to run the action depending on the previous result.
	 Not doing that and instead checking the `result` value before starting the action for instance,
	  won’t be thread-safe and someone might start the action before you.
	 
	 Or the action might get a result before you can start it!
	 
	 Never assume the end handler will be called asynchronously.
	 
	 When the end handler is called, the state of the action will either be `idleWeak` or `idleStrong` (you decide with the `weakeningMode` parameter).
	 
	 - Important: If you weaken the action instantly (`nil` delay, which is the default),
	  the only way to retrieve the result of the action is through the handler given as argument of this method.
	 A weak action always have a `nil` result. */
	public final func start(
		parameters: Parameters,
		weakeningMode: WeakeningMode = WeakeningMode.defaultMode,
		shouldJoinRunningAction: (_ currentParameters: Parameters) -> Bool = { _ in false },
		shouldRetrievePreviousRun: (_ previousParameters: Parameters?, _ runWasSuccessful: Bool) -> Bool = { _, _ in false },
		handler: ((_ result: Result<Results, Error>) -> Void)?
	) {
		/* Pre-checks before running the action */
		let (shouldLaunch, handlerCallArgument) = stateSyncQueue.sync{ () -> (Bool, Result<Results, Error>?) in
			guard !currentState.isRunning else {
				/* If we’re running, let’s check whether the client wants to join the currently running action and be called when we’re done. */
				if shouldJoinRunningAction(self.latestParameters!) {
					if let h = handler {endHandlers.append(h)}
					else               {/*OfficeKitConfig.logger?.warning("Asked to join a running action of type \(type(of: self)) for subject \(self.subject) but no handler given…")*/}
					return (false, nil)
				} else {
					return (false, .failure(ActionError.actionIsAlreadyRunning))
				}
			}
			
			if let r = currentState.result {
				/* If we’re not running but have a result from a previous run, let’s see if the client wants to retrieve the result directly. */
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
		let privateHandler = { (result: Result<Results, Error>) -> Void in
			let savedEndHandlers = self.stateSyncQueue.sync{ () -> Array<(_ result: Result<Results, Error>) -> Void> in
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
		/* Start the action */
		Task{
			await privateHandler(Result{ try await action.execute(parameters: parameters) })
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
					throw ActionError.actionIsNotFinished
			}
		}
	}
	
	/** Clears the latestParameters variable. If the action is running, throws. */
	public final func clearLatestParameters() throws {
		try stateSyncQueue.sync{
			guard !currentState.isRunning else {throw ActionError.actionIsNotFinished}
			latestParameters = nil
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum State {
		
		/** The action is not running and has no forced reference to itself. */
		case idleWeak
		/**
		 The action is not running and has a forced reference to itself (the action keeps a strong reference to itself).
		 If the weakening timer is nil, the action will never weaken on its own. */
		case idleStrong(result: Result<Results, Error>, weakeningTimer: DispatchSourceTimer?, selfReference: ActionExecutor)
		
		/** The action is running (and has a forced reference to itself). */
		case running(selfReference: ActionExecutor)
		
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
		
		var result: Result<Results, Error>? {
			switch self {
				case .idleWeak, .running:                                             return nil
				case .idleStrong(result: let r, weakeningTimer: _, selfReference: _): return r
			}
		}
		
		var timer: DispatchSourceTimer? {
			switch self {
				case .running, .idleWeak:      return nil
				case .idleStrong(_, let t, _): return t
			}
		}
		
	}
	
	private let stateSyncQueue = DispatchQueue(label: "Action executor \(UUID())", attributes: [/*serial*/])
	private var currentState: State {
		willSet {currentState.timer?.cancel()}
		didSet  {currentState.timer?.resume()}
	}
	/** **Must** be changed on the `stateSyncQueue`. */
	private var endHandlers = Array<(_ result: Result<Results, Error>) -> Void>()
	
}
