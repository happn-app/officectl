/*
 * Connector+Future.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import NIO



public extension Connector {
	
	func connect(scope: ScopeType, forceReconnect: Bool = false, eventLoop: EventLoop, dispatchQueue: DispatchQueue = defaultDispatchQueueForFutureSupport) -> EventLoopFuture<Void> {
		let promise: EventLoopPromise<Void> = eventLoop.newPromise()
		connect(scope: scope, forceReconnect: forceReconnect, handlerQueue: dispatchQueue, handler: { result in
			if let error = result.failureValue {promise.fail(error: error)}
			else                               {promise.succeed(result: ())}
		})
		return promise.futureResult
	}
	
	func disconnect(scope: ScopeType? = nil, forceDisconnect: Bool = false, eventLoop: EventLoop, dispatchQueue: DispatchQueue = defaultDispatchQueueForFutureSupport) -> EventLoopFuture<Void> {
		let promise: EventLoopPromise<Void> = eventLoop.newPromise()
		disconnect(scope: scope, forceDisconnect: forceDisconnect, handlerQueue: dispatchQueue, handler: { result in
			if let error = result.failureValue {promise.fail(error: error)}
			else                               {promise.succeed(result: ())}
		})
		return promise.futureResult
	}
	
}
