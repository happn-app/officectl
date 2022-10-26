/*
 *  Errors.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/03.
 */

import Foundation



public enum OfficeKitError : Error, Sendable {
	
	case invalidJSONEncodedUserWrapper
	
	/** Error thrown by `logicalUser(fromWrappedUser:, hints:)` when the the conversion is not possible (missing info to compute id of user, for instance). */
	case cannotCreateLogicalUserFromWrappedUser
	var isCannotCreateLogicalUserFromWrappedUser: Bool {
		if case .cannotCreateLogicalUserFromWrappedUser = self {return true}
		else                                                   {return false}
	}
	
	/** Multiple errors are reported (e.g. when something is tried on multiple sources and fails on all of them). */
	case errorCollection([Error])
	
}

typealias Err = OfficeKitError
