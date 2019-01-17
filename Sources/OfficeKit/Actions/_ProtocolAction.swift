/*
 * _ProtocolAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/01/2019.
 */

import Foundation

import AsyncOperationResult
import SemiSingleton



/* Some test I did with a protocol-based action (the Action object holds an
 * action engine and the engine runs the action).
 *
 * This seemed like a good idea, but engines are re-created on the fly and
 * cannot hold a persistent reference to, say, a dependent action. Furthermore
 * the engine is limited in its results and accessing details of the results
 * (e.g. the action failed for something, succeeded somewhere else, can be
 * retried) can be tricky. */



@available(*, deprecated, message: "This was a test. Don’t use it.")
public protocol _ActionEngine {
	
	/* The idea is an action has a subject and parameters. The subject is the
	 * object on which the uniquing will be done. No two actions should run with
	 * the same subject at a given time. The parameters are the parameters needed
	 * to run the action.
	 *
	 * Example: In the case of a reset password action, the subject type is a
	 *          user. The parameters are simply the new password. */
	
	associatedtype SubjectType: Hashable
	associatedtype ParametersType
	
	associatedtype ResultType
	
	init(subject: SubjectType, parameters: ParametersType)
	
	func execute(handler: @escaping (AsyncOperationResult<ResultType>) -> Void) throws
	
}

@available(*, unavailable, message: "This was a test. Don’t use it.")
public final class _Action<EngineType : _ActionEngine> : SemiSingleton, HasResult {
	
	public typealias SemiSingletonKey = EngineType.SubjectType
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public typealias ResultType = EngineType.ResultType
	
	public let subject: EngineType.SubjectType
	public private(set) var currentParameters: EngineType.ParametersType?
	
	public var isExecuting: Bool {
		return stateSyncQueue.sync{ _isExecuting }
	}
	
	public init(key: EngineType.SubjectType, additionalInfo: Void, store: SemiSingletonStore) {
		stateSyncQueue = DispatchQueue(label: "State Sync Queue for Action With Key \(key)", attributes: [/*serial*/])
		
		subject = key
	}
	
	public func resultOrThrow() throws -> EngineType.ResultType {
		throw OperationIsNotFinishedError()
	}
	
	/** Start the action.
	
	If you try to start a running action, the handler will be called with an
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
	public func execute(parameters: EngineType.ParametersType, handler: ((_ result: AsyncOperationResult<ResultType>) -> Void)?) {
		/* Set ourselves running if not already running, fail start otherwise. */
		let newEngine = stateSyncQueue.sync{ () -> EngineType? in
			guard currentEngine == nil else {return nil}
			
			let newEngine = EngineType(subject: subject, parameters: parameters)
			currentParameters = parameters
			currentEngine = newEngine
			return newEngine
		}
		guard let engine = newEngine else {
			handler?(.error(OperationAlreadyInProgressError()))
			return
		}
		
		/* Start the action. */
		let privateHandler = { (result: AsyncOperationResult<ResultType>) -> Void in
			self.stateSyncQueue.sync{
				self.currentParameters = nil
				self.currentEngine = nil
			}
			
			handler?(result)
		}
		do {
			try engine.execute(handler: privateHandler)
		} catch {
			privateHandler(.error(error))
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var stateSyncQueue: DispatchQueue
	private var currentEngine: EngineType?
	
	private var _isExecuting: Bool {
		return currentEngine != nil
	}
	
}
