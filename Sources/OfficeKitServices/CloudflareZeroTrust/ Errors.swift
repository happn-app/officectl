/*
 *  Errors.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/27.
 */

import Foundation



public enum CloudflareZeroTrustOfficeError : Error, Sendable {
	
	case invalidID(String)
	
	case notImplemented
	
}

typealias Err = CloudflareZeroTrustOfficeError
