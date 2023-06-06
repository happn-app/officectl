/*
 *  Errors.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



public enum SynologyOfficeError : Error, Sendable {
	
	case dsmURLIsInvalid
	
	case apiLoginInvalidCreds
	case apiLoginAccountDisabled
	case apiLoginPermissionDenied
	case apiLoginNeeds2FA
	case apiLoginFailed2FA
	case apiLoginEnforce2FA
	case apiLoginForbiddenIP
	case apiLoginExpiredPasswordAndCannotChange
	case apiLoginExpiredPassword
	case apiLoginPasswordMustBeChanged
	case apiUnknownError(SynologyApiError)
	
	case notConnected
	
	case invalidPersistentID
	case internalError
	
	case __notImplemented
	
}

typealias Err = SynologyOfficeError
