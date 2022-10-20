/*
 *  Errors.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/03.
 */

import Foundation



public enum OfficeKitError : Error, Sendable {
	
	case invalidJSONUserWrapper
	
}

typealias Err = OfficeKitError
