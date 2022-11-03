/*
 *  Errors.swift
 * EmailOfficeService
 *
 * Created by François Lamboley on 2022/11/02.
 */

import Foundation

@preconcurrency import GenericJSON
import OfficeKit2



public enum EmailOfficeServiceError : Error, Sendable {
	
	case invalidEmail(String)
	case invalidJSONRepresentation(JSON)
	case invalidWrappedUser(UserWrapper)
	
	case unsupportedOperation
	
}

typealias Err = EmailOfficeServiceError
