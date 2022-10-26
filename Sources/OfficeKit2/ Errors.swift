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
		/* We create a special computed var because I’m pretty sure we’ll have cases with arguments some day… */
		if case .cannotCreateLogicalUserFromWrappedUser = self {return true}
		else                                                   {return false}
	}
	
}

typealias Err = OfficeKitError
