/*
 *  Errors.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation

import Email



public enum HappnOfficeError : Error, Sendable {
	
	case invalidEmail(String)
	case notConnected
	
	case tooManyUsersFromAPI(id: Email)
	case apiError
	
	/* TODO: Delete this. */
	case unsupportedOperation
	
}

typealias Err = HappnOfficeError
