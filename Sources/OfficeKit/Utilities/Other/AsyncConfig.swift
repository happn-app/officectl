/*
 * AsyncConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import NIO



public struct AsyncConfig {
	
	public var eventLoopGroup: EventLoopGroup
	public var eventLoop: EventLoop {
		return eventLoopGroup.next()
	}
	
	public var defaultDispatchQueue: DispatchQueue
	public var defaultOperationQueue: OperationQueue
	
	public init(eventLoopGroup elg: EventLoopGroup, defaultDispatchQueue dispatchQueue: DispatchQueue, defaultOperationQueue operationQueue: OperationQueue) {
		eventLoopGroup = elg
		defaultDispatchQueue = dispatchQueue
		defaultOperationQueue = operationQueue
	}
	
}
