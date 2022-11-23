/*
 *  Errors.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation



public enum GoogleOfficeError : Error, Sendable {
	
	case unsupportedOperation
	
}

typealias Err = GoogleOfficeError
