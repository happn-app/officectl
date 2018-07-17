/*
 * CommandOperation.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation

import AsyncOperationResult
import Guaka
import NIO
import RetryingOperation

import OfficeKit



@available(*, deprecated, message: "Use NIO’s Promises now.")
class CommandOperation : RetryingOperation {
	
	let command: Command
	let flags: Flags
	let arguments: [String]
	
	init(command c: Command, flags f: Flags, arguments args: [String]) {
		command = c
		flags = f
		arguments = args
	}
	
}

func execute(command: Command, with future: EventLoopFuture<Void>) {
	do    {try future.wait()}
	catch {command.fail(statusCode: (error as NSError).code, errorMessage: error.localizedDescription)}
}

/** Call this in the “run” block of a command. */
func execute(operation op: CommandOperation) {
	let queue = OperationQueue()
	queue.addOperations(op.selfAndRecursiveDependencies, waitUntilFinished: false)
	repeat {
		RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 0.1))
	} while !op.isFinished
}

extension Operation {
	
	var selfAndRecursiveDependencies: [Operation] {
		return [self] + dependencies.flatMap{ $0.selfAndRecursiveDependencies }
	}
	
}
