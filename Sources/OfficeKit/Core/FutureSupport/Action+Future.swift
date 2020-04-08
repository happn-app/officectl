/*
 * Action+EventLoopFuture.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/01/2019.
 */

import Foundation

import NIO



extension Action {
	
	public func start(parameters: ParametersType, weakeningMode: WeakeningMode = WeakeningMode.defaultMode, shouldJoinRunningAction: (_ currentParameters: ParametersType) -> Bool = { _ in false }, eventLoop: EventLoop) -> EventLoopFuture<ResultType> {
		let promise = eventLoop.makePromise(of: ResultType.self)
		
		start(parameters: parameters, weakeningMode: weakeningMode, shouldJoinRunningAction: shouldJoinRunningAction, handler: { result in
			switch result {
			case .success(let r): promise.succeed(r)
			case .failure(let e): promise.fail(e)
			}
		})
		
		return promise.futureResult
	}
	
}
