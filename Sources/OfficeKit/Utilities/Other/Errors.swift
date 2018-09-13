/*
 * OperationIsNotFinishedError.swift
 * OfficeKit
 *
 * Created by François Lamboley on 12/07/2018.
 */

import Foundation



public struct OperationIsNotFinishedError : Error {
}

public struct InternalError : Error {
	
	public let message: String?
	
	public init(message m: String? = nil) {
		message = m
	}
	
}
