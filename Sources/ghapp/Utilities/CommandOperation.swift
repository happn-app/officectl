/*
 * CommandOperation.swift
 * ghapp
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation

import AsyncOperationResult
import Guaka
import RetryingOperation



class CommandOperation : RetryingOperation {
	
	let command: Command
	let flags: Flags
	let arguments: [String]
	
	init(command c: Command, flags f: Flags, arguments args: [String]) {
		command = c
		flags = f
		arguments = args
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
}

/** Call this in the “run” block of a command. */
func execute(operation op: CommandOperation) {
	let queue = OperationQueue()
	queue.addOperations(op.selfAndRecursiveDependencies, waitUntilFinished: false)
	repeat {
		RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 0.1))
	} while !op.isFinished
}
