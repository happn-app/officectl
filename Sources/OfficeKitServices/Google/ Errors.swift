/*
 *  Errors.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation



public enum GoogleOfficeError : Error, Sendable {
	
	case invalidEmail(String)
	
	case invalidConnectorCredentials
	case unsupportedTokenType(String)
	case unsupportedOperation
	
	case cannotParseDateFromGoogle(String)
	
	case noPersistentID
	
	case notConnected
	
}

typealias Err = GoogleOfficeError
