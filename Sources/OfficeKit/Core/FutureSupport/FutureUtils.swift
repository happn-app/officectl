/*
 * FutureUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/01/2019.
 */

import Foundation

import NIO



public let defaultDispatchQueueForFutureSupport = DispatchQueue(label: "Default Dispatch Queue for Futures")
public let defaultOperationQueueForFutureSupport = OperationQueue(name_OperationQueue: "Default Operation Queue for Futures")

public extension EventLoopFuture {
	
	/** Returns a futures that _never_ fails and contains the result of all the
	given futures, in the order they were given.
	
	- Important: Test the order thing; I don’t remember for sure the order stays
	the same, though I don’t see the point of the method if it does not. */
	static func waitAll(_ futures: [EventLoopFuture<T>], eventLoop: EventLoop) -> EventLoopFuture<[Result<T, Error>]> {
		/* No need for this assert, we hop the future to the event loop. */
//		assert(futures.reduce(true, { val, future in val && future.eventLoop === eventLoop }))
		let f0 = eventLoop.newSucceededFuture(result: [Swift.Result<T, Error>]())
		
		let body = futures
		.map{ $0.hopTo(eventLoop: eventLoop) }
		.reduce(f0, { (result: EventLoopFuture<[Result<T, Error>]>, newFuture: EventLoopFuture<T>) -> EventLoopFuture<[Result<T, Error>]> in
			return result
			.then{ results in
				newFuture
				.map{ success in
					return results + [.success(success)]
				}
				.mapIfError{
					return results + [.failure($0)]
				}
			}
		})
		
		return body
	}
	
}
