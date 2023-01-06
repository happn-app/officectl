/*
 *  Errors.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import OfficeKit2



public enum LDAPOfficeError : Error, Sendable {
	
	case notConnected
	
	case valueIsNotSingleData
	case valueIsNotSingleString
	case valueIsNotStrings
	case valueIsDoesNotContainStrings
	case valueIsNotEmails
	
	case internalError
	
}

typealias Err = LDAPOfficeError
