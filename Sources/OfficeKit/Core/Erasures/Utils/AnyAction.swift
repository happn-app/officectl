/*
 * AnyAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



public protocol AnyAction {
	
	associatedtype ParametersType
	associatedtype ResultType
	
	var isExecuting: Bool {get}
	var latestParameters: ParametersType? {get}
	var result: Result<ResultType, Error>? {get}
	
	func start(
		parameters: ParametersType,
		weakeningMode: WeakeningMode,
		shouldJoinRunningAction: (_ currentParameters: ParametersType) -> Bool,
		shouldRetrievePreviousRun: (_ previousParameters: ParametersType?, _ runWasSuccessful: Bool) -> Bool,
		handler: ((_ result: Result<ResultType, Error>) -> Void)?
	)
	
	func weaken() throws
	func clearLatestParameters() throws
	
}
