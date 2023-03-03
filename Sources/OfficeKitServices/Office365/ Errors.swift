/*
 *  Errors.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation



public enum Office365OfficeError : Error, Sendable {
	
	case invalidEmail(String)
	
	case unsupportedOperation
	case unsupportedTokenType(String)
	
	case notConnected
	
	case __notImplemented
	
}

typealias Err = Office365OfficeError
