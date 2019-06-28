/*
 * ResetPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/06/2019.
 */

import Foundation



/* Type erasure for a reset password action. */
public protocol ResetPasswordAction {
	
	var isExecuting: Bool {get}
	var latestParameters: String? {get}
	
	func start(parameters: String, weakeningMode: WeakeningMode, handler: ((_ result: Result<Void, Error>) -> Void)?)
	
	func weaken() throws
	func clearLatestParameters() throws
	
}
