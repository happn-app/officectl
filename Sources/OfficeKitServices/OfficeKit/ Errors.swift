/*
 *  Errors.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation



public enum OfficeKitOfficeError : Error, Sendable {
	
	case invalidUserIDFormat
	
	case internalError
	
	case __notImplemented
	
}

typealias Err = OfficeKitOfficeError
