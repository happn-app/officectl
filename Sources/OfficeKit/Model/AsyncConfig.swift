/*
 * AsyncConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import NIO
import Service



public struct AsyncConfig : ServiceType {
	
	public static func makeService(for worker: Container) throws -> AsyncConfig {
		let oq = OperationQueue()
		oq.name = "Default Background Operation Queue"
		let dq = DispatchQueue(label: "Default Background Dispatch Queue")
		return AsyncConfig(dispatchQueue: dq, operationQueue: oq)
	}
	
	public var dispatchQueue: DispatchQueue
	public var operationQueue: OperationQueue
	
	public init(dispatchQueue dq: DispatchQueue, operationQueue oq: OperationQueue) {
		dispatchQueue = dq
		operationQueue = oq
	}
	
}
