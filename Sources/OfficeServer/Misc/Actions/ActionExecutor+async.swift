/*
 * ActionExecutor+async.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation



extension ActionExecutor {
	
	public func start(
		parameters: Parameters,
		weakeningMode: WeakeningMode = WeakeningMode.defaultMode,
		shouldJoinRunningAction: (_ currentParameters: Parameters) -> Bool = { _ in false },
		shouldRetrievePreviousRun: (_ previousParameters: Parameters?, _ runWasSuccessful: Bool) -> Bool = { _, _ in false }
	) async throws -> Results {
		return try await withCheckedThrowingContinuation{ continuation in
			start(parameters: parameters, weakeningMode: weakeningMode, shouldJoinRunningAction: shouldJoinRunningAction, shouldRetrievePreviousRun: shouldRetrievePreviousRun, handler: { continuation.resume(with: $0) })
		}
	}
	
}
