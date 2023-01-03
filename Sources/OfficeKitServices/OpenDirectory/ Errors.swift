/*
 *  Errors.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation



public enum OpenDirectoryOfficeError : Error, Sendable {
	
	case notConnected
	
	case notImplemented
	
}

typealias Err = OpenDirectoryOfficeError
