/*
 *  Errors.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/27.
 */

import Foundation



public enum CloudflareZeroTrustOfficeError : Error, Sendable {
	
	/** Thrown at init time, if the account ID is not a valid path component. */
	case invalidAccountID(String)
	
	case invalidID(String)
	
	case internalError(String)
	case notImplemented
	
}

typealias Err = CloudflareZeroTrustOfficeError
