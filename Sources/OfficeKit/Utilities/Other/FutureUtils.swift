/*
 * FutureUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/01/2019.
 */

import Foundation

import NIO
import Vapor



public extension EventLoopFuture {
	
	static func waitAll(_ futures: [EventLoopFuture<T>], eventLoop: EventLoop) -> EventLoopFuture<[FutureResult<T>]> {
		/* No need for this assert, we hop the future to the event loop. */
//		assert(futures.reduce(true, { val, future in val && future.eventLoop === eventLoop }))
		let f0 = eventLoop.newSucceededFuture(result: [FutureResult<T>]())
		
		let body = futures
		.map{ $0.hopTo(eventLoop: eventLoop) }
		.reduce(f0, { (result: EventLoopFuture<[FutureResult<T>]>, newFuture: EventLoopFuture<T>) -> EventLoopFuture<[FutureResult<T>]> in
			return result
			.then{ results in
				newFuture
				.map{ success in
					return results + [.success(success)]
				}
				.mapIfError{
					return results + [.error($0)]
				}
			}
		})
		
		return body
	}
	
}
