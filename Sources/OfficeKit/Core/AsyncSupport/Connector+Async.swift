/*
 * Connector+Async.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import NIO



public extension Connector {
	
	func connect(scope: ScopeType, forceReconnect: Bool = false, dispatchQueue: DispatchQueue = defaultDispatchQueueForFutureSupport) async throws {
		_ = try await withCheckedThrowingContinuation{ continuation in
			connect(scope: scope, forceReconnect: forceReconnect, handlerQueue: dispatchQueue, handler: { continuation.resume(with: $0) })
		}
	}
	
	func disconnect(scope: ScopeType? = nil, forceDisconnect: Bool = false, dispatchQueue: DispatchQueue = defaultDispatchQueueForFutureSupport) async throws {
		_ = try await withCheckedThrowingContinuation{ continuation in
			disconnect(scope: scope, forceDisconnect: forceDisconnect, handlerQueue: dispatchQueue, handler: { continuation.resume(with: $0) })
		}
	}
	
}
