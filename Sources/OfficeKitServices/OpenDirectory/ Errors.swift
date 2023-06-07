/*
 *  Errors.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation

import OfficeKit



public enum OpenDirectoryOfficeError : Error, Sendable {
	
	case notConnected
	
	case invalidPersistentID
	case triedToChangeRecordName
	
	case internalError
	
}

typealias Err = OpenDirectoryOfficeError
