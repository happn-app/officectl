/*
 *  Errors.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/28.
 */

import Foundation



public enum GitHubOfficeError : Error, Sendable {
	
	case invalidPersistentID
	
	case notConnected
	
	case loginNotFound
	
	case unsupportedOperation
	case notImplemented
	
}

typealias Err = GitHubOfficeError
