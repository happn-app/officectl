/*
 * Errors.swift
 * OfficeKit
 *
 * Created by François Lamboley on 12/07/2018.
 */

import Foundation



public struct ErrorCollection : Error {
	
	let errors: [Error]
	
	public init(_ e: [Error]) {
		errors = e
	}
	
}


public struct MissingFieldError : Error {
	
	let fieldName: String
	
	public init(_ n: String) {
		fieldName = n
	}
	
}


public struct OperationIsNotFinishedError : Error {
	
	public init() {}
	
}


public struct OperationAlreadyInProgressError : Error {
	
	public init() {}
	
}


public struct NotImplementedError : Error {
	
	public init() {}
	
}


public struct NotSupportedError : Error {
	
	public let message: String?
	
	public init(message m: String? = nil) {
		message = m
	}
	
}


public struct UserAbortedError : Error {
	
	public init() {}
	
}


public struct InvalidArgumentError : Error {
	
	public let message: String?
	
	public init(message m: String? = nil) {
		message = m
	}
	
}


public struct InternalError : Error {
	
	public let message: String?
	
	public init(message m: String? = nil) {
		message = m
	}
	
}


public struct NotAvailableOnThisPlatformError : Error {
	
	public init() {}
	
}
