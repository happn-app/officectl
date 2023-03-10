/*
 * AuthRequestRetryProvider.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2023/03/10.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import RetryingOperation
import TaskQueue
import URLRequestOperation



public protocol HTTPAuthConnector : Connector {
	
	func refreshToken(requestAuthDate: Date?) async throws
	
}


public struct AuthRequestRetryProvider : RetryProvider {
	
	public let connector: any HTTPAuthConnector
	
	public init(_ connector: any HTTPAuthConnector) {
		self.connector = connector
	}
	
	public nonisolated func retryHelpers(for request: URLRequest, error: URLRequestOperationError, operation: URLRequestOperation) -> [RetryHelper]?? {
		guard error.unexpectedStatusCodeError?.actual == 401 else {
			return nil
		}
		/* Think about it, but the limit could probably be 1 here. */
		guard Self.reAuthRetryCount[operation.urlOperationIdentifier, default: 0] < 3 else {
			return nil
		}
		Self.reAuthRetryCount[operation.urlOperationIdentifier, default: 0] += 1
		return [ReAuthHelper(connector: connector, operation: operation)]
		
		struct ReAuthHelper : RetryHelper {
			
			let connector: any HTTPAuthConnector
			let operation: URLRequestOperation
			
			init(connector: any HTTPAuthConnector, operation: URLRequestOperation) {
				self.connector = connector
				self.operation = operation
			}
			
			mutating func setup() {
				let operation = operation
				let connector = connector
				assert(task == nil)
				task = Task{
					do {
						try await connector.refreshToken(requestAuthDate: operation.latestTryStartDate)
					} catch {
						operation.retryError = error
					}
					if !Task.isCancelled {
						operation.retryNow()
					}
				}
			}
			
			mutating func teardown() {
				task?.cancel()
				task = nil
			}
			
			private var task: Task<Void, Error>?
			
		}
	}
	
	private static let reAuthRetryCount = RetryCountsHolder()
	
}
