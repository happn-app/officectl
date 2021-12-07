/*
 * HasResult.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/01/2019.
 */

import Foundation



public protocol HasResult {
	
	associatedtype ResultType
	
	var result: Result<ResultType, Error> {get}
	
}


public extension HasResult {
	
	func resultOrThrow() throws -> ResultType {
		return try result.get()
	}
	
	var resultError: Error? {
		return result.failureValue
	}
	
}
