/*
 * OfficeKitErrors.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/01/04.
 */

import Foundation



/**
 All of the errors thrown by the module should have this type.
 Currently this is far from the case. */
public enum OfficeKitError : Error {
	
	case genericError(String)
	
}

typealias Err = OfficeKitError
