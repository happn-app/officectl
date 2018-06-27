/*
 * HandlerOperation.swift
 * officectl
 *
 * Created by François Lamboley on 14/06/2018.
 */

import Foundation

import RetryingOperation



public class HandlerOperation : RetryingOperation {
	
	public typealias StartHandler = (_ stopHandler: @escaping () -> Void) -> Void
	
	public init(startHandler h: @escaping StartHandler) {
		startHandler = h
	}
	
	override public func startBaseOperation(isRetry: Bool) {
		startHandler(baseOperationEnded)
	}
	
	override public var isAsynchronous: Bool {
		return true
	}
	
	private let startHandler: StartHandler
	
}
