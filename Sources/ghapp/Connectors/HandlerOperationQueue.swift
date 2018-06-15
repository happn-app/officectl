/*
 * ConnectorHelper.swift
 * ghapp
 *
 * Created by François Lamboley on 14/06/2018.
 */

import Foundation

import RetryingOperation



public class HandlerOperationQueue {
	
	public init(name: String) {
		operationQueue = OperationQueue()
		operationQueue.name = "Operation Queue for HandlerOperationQueue \(name)"
		operationQueue.maxConcurrentOperationCount = 1
	}
	
	public func addToQueue(handler: @escaping (_ stopHandler: @escaping () -> Void) -> Void) {
		operationQueue.addOperation(HandlerOperation(startHandler: handler))
	}
	
	private let operationQueue: OperationQueue
	
}


private class HandlerOperation : RetryingOperation {
	
	let startHandler: (_ stopHandler: @escaping () -> Void) -> Void
	
	init(startHandler h: @escaping (_ stopHandler: @escaping () -> Void) -> Void) {
		startHandler = h
	}
	
	override func startBaseOperation(isRetry: Bool) {
		startHandler(baseOperationEnded)
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
}
