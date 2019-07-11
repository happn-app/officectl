/*
 * Action+Future.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/01/2019.
 */

import Foundation

import NIO



extension Action {
	
	public func start(parameters: ParametersType, weakeningMode: WeakeningMode = WeakeningMode.defaultMode, eventLoop: EventLoop) -> EventLoopFuture<ResultType> {
		let promise = eventLoop.newPromise(ResultType.self)
		
		start(parameters: parameters, weakeningMode: weakeningMode, handler: { result in
			switch result {
			case .success(let r): promise.succeed(result: r)
			case .failure(let e): promise.fail(error: e)
			}
		})
		
		return promise.futureResult
	}
	
}
