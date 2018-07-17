/*
 * Connector+Future.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import NIO



public extension Connector {
	
	func connect(scope: ScopeType, asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
		let promise: EventLoopPromise<Void> = asyncConfig.eventLoop.newPromise()
		connect(scope: scope, handlerQueue: asyncConfig.defaultDispatchQueue, handler: { error in
			if let error = error {promise.fail(error: error)}
			else                 {promise.succeed(result: ())}
		})
		return promise.futureResult
	}
	
	func disconnect(asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
		let promise: EventLoopPromise<Void> = asyncConfig.eventLoop.newPromise()
		disconnect(handlerQueue: asyncConfig.defaultDispatchQueue, handler: { error in
			if let error = error {promise.fail(error: error)}
			else                 {promise.succeed(result: ())}
		})
		return promise.futureResult
	}
	
}
