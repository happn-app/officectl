/*
 * ResetPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/06/2019.
 */

import Foundation

import NIO



/* Type erasure for a reset password action.
 *
 * Note: I’d have loved to have the inheritance commented below, but Swift considers the protocol to have associated type requirements still,
 * even with the `where` clause that in effect drops the associated types, so I can’t do that and I have to “duplicate” the AnyAction protocol.
 * IMHO this is a Swift bug, but this is debatable. */
public protocol ResetPasswordAction/* : AnyAction where ParametersType == String, ResultType == Void */ {
	
	var isWeak: Bool {get}
	var isExecuting: Bool {get}
	var latestParameters: String? {get}
	var result: Result<Void, Error>? {get}
	
	func start(parameters: String, weakeningMode: WeakeningMode, shouldJoinRunningAction: (_ currentParameters: String) -> Bool, shouldRetrievePreviousRun: (_ previousParameters: String?, _ runWasSuccessful: Bool) -> Bool) async throws
	func start(parameters: String, weakeningMode: WeakeningMode, shouldJoinRunningAction: (_ currentParameters: String) -> Bool, shouldRetrievePreviousRun: (_ previousParameters: String?, _ runWasSuccessful: Bool) -> Bool, handler: ((_ result: Result<Void, Error>) -> Void)?)
	
	func weaken() throws
	func clearLatestParameters() throws
	
}


public extension ResetPasswordAction {
	
	func start(parameters newPass: String, weakeningMode: WeakeningMode) async throws {
		try await start(parameters: newPass, weakeningMode: weakeningMode, shouldJoinRunningAction: { currentResetPassword in newPass == currentResetPassword }, shouldRetrievePreviousRun: { _, _ in false })
	}
	
	func start(parameters newPass: String, weakeningMode: WeakeningMode, handler: ((_ result: Result<Void, Error>) -> Void)?) {
		return start(parameters: newPass, weakeningMode: weakeningMode, shouldJoinRunningAction: { currentResetPassword in newPass == currentResetPassword }, shouldRetrievePreviousRun: { _, _ in false }, handler: handler)
	}
	
}
