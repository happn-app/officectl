/*
 * Action+Future.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/01/2019.
 */

import Foundation

import NIO



extension OldAction {
	
	public func start(config: StartConfigType, weakeningDelay: TimeInterval?, eventLoop: EventLoop) -> EventLoopFuture<ResultType> {
		let promise = eventLoop.newPromise(ResultType.self)
		
		start(config: config, weakeningDelay: weakeningDelay, handler: { result in
			switch result {
			case .success(let r): promise.succeed(result: r)
			case .error(let e):   promise.fail(error: e)
			}
		})
		
		return promise.futureResult
	}
	
}
