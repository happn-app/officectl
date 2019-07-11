/*
 * FutureUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/01/2019.
 */

import Foundation

import NIO
import Async



public let defaultDispatchQueueForFutureSupport = DispatchQueue(label: "Default Dispatch Queue for Futures")
public let defaultOperationQueueForFutureSupport = OperationQueue(name_OperationQueue: "Default Operation Queue for Futures")

public extension Future {
	
	static func waitAll(_ futures: [Future<T>], eventLoop: EventLoop) -> Future<[FutureResult<T>]> {
		/* No need for this assert, we hop the future to the event loop. */
//		assert(futures.reduce(true, { val, future in val && future.eventLoop === eventLoop }))
		let f0 = eventLoop.newSucceededFuture(result: [FutureResult<T>]())
		
		let body = futures
		.map{ $0.hopTo(eventLoop: eventLoop) }
		.reduce(f0, { (result: Future<[FutureResult<T>]>, newFuture: Future<T>) -> Future<[FutureResult<T>]> in
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
