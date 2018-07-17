/*
 * Operation2Future.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation

import NIO



public extension EventLoop {
	
	func future<T, O : Operation>(from operation: O, queue q: OperationQueue, resultRetriever: @escaping (_ operation: O) throws -> T) -> EventLoopFuture<T> {
		let promise: EventLoopPromise<T> = newPromise()
		let resultRetrieverOperation = BlockOperation{
			do    {promise.succeed(result: try resultRetriever(operation))}
			catch {promise.fail(error: error)}
		}
		resultRetrieverOperation.addDependency(operation)
		q.addOperations([operation, resultRetrieverOperation], waitUntilFinished: false)
		return promise.futureResult
	}
	
}
