/*
 * Operation2Future.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation

import AsyncOperationResult
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
	
	/** Executes all the operations in order and stop at first failure. The
	future only succeeds when all operations succeed. */
	func future<T, O : Operation>(from operations: [O], queue q: OperationQueue, resultRetriever: @escaping (_ operation: O) throws -> T) -> EventLoopFuture<[T]> {
		let futures = operations.map{ future(from: $0, queue: q, resultRetriever: resultRetriever) }
		
		let initialFuture = newSucceededFuture(result: [T]())
		return initialFuture.fold(futures, with: { (currentResults, newResult) -> EventLoopFuture<[T]> in
			return self.newSucceededFuture(result: currentResults + [newResult])
		})
	}
	
	/** Executes all operations in parallel and returns all the results or
	failures. The future itself never fails.
	
	- warning: The order of the results is undefined! (TODO: Make it defined…) */
	func future<T, O : Operation>(from operations: [O], queue q: OperationQueue, resultRetriever: @escaping (_ operation: O) throws -> T) -> EventLoopFuture<[AsyncOperationResult<T>]> {
		let promise: EventLoopPromise<[AsyncOperationResult<T>]> = newPromise()
		let resultRetrieverOperation = BlockOperation{
			var results = [AsyncOperationResult<T>]()
			for o in operations {
				do    {results.append(.success(try resultRetriever(o)))}
				catch {results.append(.error(error))}
			}
			promise.succeed(result: results)
		}
		operations.forEach{ resultRetrieverOperation.addDependency($0) }
		q.addOperations(operations + [resultRetrieverOperation], waitUntilFinished: false)
		return promise.futureResult
	}
	
}
