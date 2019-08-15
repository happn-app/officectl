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
	static func waitAll(_ futures: [EventLoopFuture<Value>], eventLoop: EventLoop) -> EventLoopFuture<[Result<Value, Error>]> {
		/* No need for this assert, we hop the future to the event loop. */
//		assert(futures.reduce(true, { val, future in val && future.eventLoop === eventLoop }))
		let f0 = eventLoop.makeSucceededFuture([Swift.Result<Value, Error>]())
		
		let body = futures
		.map{ $0.hop(to: eventLoop) }
		.reduce(f0, { (result: EventLoopFuture<[Result<Value, Error>]>, newFuture: EventLoopFuture<Value>) -> EventLoopFuture<[Result<Value, Error>]> in
			return result
			.flatMap{ results in
				newFuture
				.map{ success in
					return results + [.success(success)]
				}
				.flatMapErrorThrowing{
					return results + [.failure($0)]
				}
			}
		})
		
		return body
	}
	
	#warning("TODO Swift 5.1: It will be highly probably that we’ll be able to return “some Sequence” instead of an explicit Array, which would avoid a useless conversion")
	static func waitAll<IdType>(_ idFutureTuples: [(IdType, EventLoopFuture<Value>)], eventLoop: EventLoop) -> EventLoopFuture<[(IdType, Result<Value, Error>)]> {
		let ids = idFutureTuples.map{ $0.0 }
		let futures = idFutureTuples.map{ $0.1 }
		return waitAll(futures, eventLoop: eventLoop).map{ futureResults in
			Array(zip(ids, futureResults))
		}
	}
	
	static func waitAll<IdType : Hashable>(_ futuresById: [IdType: EventLoopFuture<Value>], eventLoop: EventLoop) -> EventLoopFuture<[IdType: Result<Value, Error>]> {
		return waitAll(futuresById.map{ $0 }, eventLoop: eventLoop).map{ try! $0.group(by: { $0.0 }, mappingValues: { $0.1 }) }
	}
	
}
