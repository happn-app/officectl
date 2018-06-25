/*
 * ConnectorHelper.swift
 * ghapp
 *
 * Created by François Lamboley on 14/06/2018.
 */

import Foundation

import RetryingOperation



public class HandlerOperationQueue {
	
	public typealias StartHandler = (_ stopHandler: @escaping () -> Void) -> Void
	
	public init(name: String) {
		operationQueue = OperationQueue()
		operationQueue.name = "Operation Queue for HandlerOperationQueue \(name)"
		operationQueue.maxConcurrentOperationCount = 1
	}
	
	public func addToQueue(handler: @escaping StartHandler) {
		operationQueue.addOperation(HandlerOperation(startHandler: handler))
	}
	
	private let operationQueue: OperationQueue
	
}


private class HandlerOperation : RetryingOperation {
	
	let startHandler: HandlerOperationQueue.StartHandler
	
	init(startHandler h: @escaping HandlerOperationQueue.StartHandler) {
		startHandler = h
	}
	
	override func startBaseOperation(isRetry: Bool) {
		startHandler(baseOperationEnded)
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
}
