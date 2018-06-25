/*
 * HandlerOperationQueue.swift
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
	
	public func addToQueue(handler: @escaping HandlerOperation.StartHandler) {
		operationQueue.addOperation(HandlerOperation(startHandler: handler))
	}
	
	private let operationQueue: OperationQueue
	
}
