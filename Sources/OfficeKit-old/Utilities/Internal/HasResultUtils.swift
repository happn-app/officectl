/*
 * HasResultUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2021/12/7.
 */

import Foundation

import HasResult



extension HasResult {
	
	func resultOrThrow() throws -> ResultType {
		return try result.get()
	}
	
	var resultError: Error? {
		return result.failureValue
	}
	
}
