/*
 * AsyncConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import NIO
import Vapor



public struct AsyncConfig : Service {
	
	public var eventLoop: EventLoop
	public var dispatchQueue: DispatchQueue
	public var operationQueue: OperationQueue
	
	public init(eventLoop el: EventLoop, dispatchQueue dq: DispatchQueue, operationQueue oq: OperationQueue) {
		eventLoop = el
		dispatchQueue = dq
		operationQueue = oq
	}
	
}

public struct AsyncConfigFactory : ServiceFactory {
	
	public let serviceType: Any.Type = AsyncConfig.self
	public let serviceSupports: [Any.Type] = [AsyncConfig.self]
	
	public init() {
	}
	
	public func makeService(for worker: Container) throws -> Any {
		let oq = OperationQueue()
		oq.name = "Default Background Operation Queue"
		let dq = DispatchQueue(label: "Default Background Dispatch Queue")
		return AsyncConfig(eventLoop: worker.eventLoop, dispatchQueue: dq, operationQueue: oq)
	}
	
}
