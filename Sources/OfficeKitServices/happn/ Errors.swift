/*
 *  Errors.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation



public enum HappnOfficeError : Error, Sendable {
	
	case invalidEmail(String)
	case notConnected
	
	/* TODO: Delete this. */
	case unsupportedOperation
	
}

typealias Err = HappnOfficeError
