/*
 * Operation2Future.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation

import NIO
import Async



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
	
	func future<O : Operation>(from operation: O, queue q: OperationQueue) -> EventLoopFuture<O.ResultType> where O : HasResult {
		return future(from: operation, queue: q, resultRetriever: { try $0.resultOrThrow() })
	}
	
	#warning("It is not true the operations that fail will prevent next operations to run. They WILL run but you won’t get any feedback from these runs.")
	/** Executes all the operations in order and stop at first failure (reduce
	the operations). The future only succeeds if all the operations succeed. */
	func reduce<T, O : Operation>(operations: [O], queue q: OperationQueue, resultRetriever: @escaping (_ operation: O) throws -> T) -> EventLoopFuture<[T]> {
		let futures = operations.map{ future(from: $0, queue: q, resultRetriever: resultRetriever) }
		
		return EventLoopFuture.reduce([T](), futures, eventLoop: self, { (currentResults, newResult) -> [T] in
			return currentResults + [newResult]
		})
	}
	
	/** Executes all the operations in order and stop at first failure (reduce
	the operations). The future only succeeds if all the operations succeed. */
	func reduce<O : Operation>(operations: [O], queue q: OperationQueue) -> EventLoopFuture<[O.ResultType]> where O : HasResult {
		return reduce(operations: operations, queue: q, resultRetriever: { try $0.resultOrThrow() })
	}
	
	/**
	Executes all operations in parallel and returns a future whose value is an
	array of the future results of all the operations. The results have the same
	order as the operations.
	
	Example of use, with operations returning a Boolean:
	```
	Input:                    [op1, op2]
	Returns:                  Future<[FutureResult<Bool>]>
	When the future resolves: let resultForOp1 = futureSuccess[0], resultForOp2 = futureSuccess[1]
	```
	
	- note: The future returned by this method **never** fails.
	
	- parameter operations: The list of operations to exectue.
	- parameter q: The queue on which the operations will be run.
	- parameter resultRetriever: The block that can retrieve the result from a
	finished operation. Returns the success value if the operation succeeded,
	throws if the operation failed.
	- parameter operation: The operation from which to retrieve the result.
	- returns: A future (that will never fail) whose resolution will give an
	array of future results (one result per operations given). */
	func executeAll<T, O : Operation>(_ operations: [O], queue q: OperationQueue, resultRetriever: @escaping (_ operation: O) throws -> T) -> EventLoopFuture<[FutureResult<T>]> {
		let promise: EventLoopPromise<[FutureResult<T>]> = newPromise()
		let resultRetrieverOperation = BlockOperation{
			var results = [FutureResult<T>]()
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
	
	/**
	Executes all operations in parallel and returns a future whose value is an
	array of the future results of all the operations. The results have the same
	order as the operations.
	
	Example of use, with operations returning a Boolean:
	```
	Input:                    [op1, op2]
	Returns:                  Future<[FutureResult<Bool>]>
	When the future resolves: let resultForOp1 = futureSuccess[0], resultForOp2 = futureSuccess[1]
	```
	
	- note: The future returned by this method **never** fails.
	
	- parameter operations: The list of operations to exectue.
	- parameter q: The queue on which the operations will be run.
	- returns: A future (that will never fail) whose resolution will give an
	array of future results (one result per operations given). */
	func executeAll<O : Operation>(_ operations: [O], queue q: OperationQueue) -> EventLoopFuture<[FutureResult<O.ResultType>]> where O : HasResult {
		return executeAll(operations, queue: q, resultRetriever: { try $0.resultOrThrow() })
	}
	
}
