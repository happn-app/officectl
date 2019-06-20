/*
 * Connector+Future.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import NIO



public extension Connector {
	
	func connect(scope: ScopeType, forceReconnect: Bool = false, asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
		let promise: EventLoopPromise<Void> = asyncConfig.eventLoop.newPromise()
		connect(scope: scope, forceReconnect: forceReconnect, handlerQueue: asyncConfig.dispatchQueue, handler: { _, error in
			if let error = error {promise.fail(error: error)}
			else                 {promise.succeed(result: ())}
		})
		return promise.futureResult
	}
	
	func disconnect(scope: ScopeType? = nil, forceDisconnect: Bool = false, asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
		let promise: EventLoopPromise<Void> = asyncConfig.eventLoop.newPromise()
		disconnect(scope: scope, forceDisconnect: forceDisconnect, handlerQueue: asyncConfig.dispatchQueue, handler: { _, error in
			if let error = error {promise.fail(error: error)}
			else                 {promise.succeed(result: ())}
		})
		return promise.futureResult
	}
	
}
