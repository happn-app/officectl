/*
 *  Errors.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



public enum SynologyOfficeError : Error, Sendable {
	
	case dsmURLIsInvalid
	
	case loginInvalidCreds
	case loginAccountDisabled
	case permissionDenied
	case loginNeeds2FA
	case loginFailed2FA
	case loginEnforce2FA
	case loginForbiddenIP
	case loginExpiredPasswordAndCannotChange
	case loginExpiredPassword
	case loginPasswordMustBeChanged
	case unknownCode(Int)
	
	case notConnected
	
	case internalError
	
	case __notImplemented
	
}

typealias Err = SynologyOfficeError
