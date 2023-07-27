/*
 *  Errors.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation



public enum HappnOfficeError : Error, Sendable {
	
	case invalidID(String)
	case noPersistentID
	case notConnected
	
	case apiError(code: Int, message: String)
	
	/* _Not_ the same as `OfficeKit.unsupportedOperation`. */
	case unsupportedOperation
	
}

typealias Err = HappnOfficeError
