/*
 * OperationIsNotFinishedError.swift
 * OfficeKit
 *
 * Created by François Lamboley on 12/07/2018.
 */

import Foundation



public struct MissingFieldError : Error {
	
	let fieldName: String
	
	public init(_ n: String) {
		fieldName = n
	}
	
}

public struct OperationIsNotFinishedError : Error {
	
	public init() {}
	
}

public struct NotImplementedError : Error {
	
	public init() {}
	
}

public struct InternalError : Error {
	
	public let message: String?
	
	public init(message m: String? = nil) {
		message = m
	}
	
}
