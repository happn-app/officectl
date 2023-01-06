/*
 *  Errors.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import COpenLDAP

import OfficeKit2



public enum LDAPOfficeError : Error, Sendable {
	
	case notConnected
	
	case passwordIsNotASCII
	
	case valueIsNotSingleData
	case valueIsNotSingleString
	case valueIsNotStrings
	case valueIsDoesNotContainStrings
	case valueIsNotEmails
	
	case serviceDoesNotHavePersistentID
	
	case internalError
	
	case __notImplemented
	
}

typealias Err = LDAPOfficeError


public struct OpenLDAPError : Error, Sendable {
	
	public var code: Int32
	
	internal init(code: Int32) {
		self.code = code
	}
	
	public var isInvalidPassError: Bool {
		return (code == LDAP_INVALID_CREDENTIALS)
	}
	
}
