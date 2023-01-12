/*
 * Action+Async.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/01/09.
 */

import Foundation

import NIO



extension Action {
	
	public func start(
		parameters: ParametersType,
		weakeningMode: WeakeningMode = WeakeningMode.defaultMode,
		shouldJoinRunningAction: (_ currentParameters: ParametersType) -> Bool = { _ in false },
		shouldRetrievePreviousRun: (_ previousParameters: ParametersType?, _ runWasSuccessful: Bool) -> Bool = { _, _ in false }
	) async throws -> ResultType {
		return try await withCheckedThrowingContinuation{ continuation in
			start(parameters: parameters, weakeningMode: weakeningMode, shouldJoinRunningAction: shouldJoinRunningAction, shouldRetrievePreviousRun: shouldRetrievePreviousRun, handler: { continuation.resume(with: $0) })
		}
	}
	
}
