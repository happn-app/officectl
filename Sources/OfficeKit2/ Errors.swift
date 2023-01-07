/*
 *  Errors.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/03.
 */

import Foundation



public enum OfficeKitError : Error, Sendable {
	
	case ldapDNParseFailure(reason: String)
	case ldapInvalidAttributeDescriptionOptions([String])
	
	/**
	 Error thrown by ``UserService/existingUser(fromID:propertiesToFetch:using:)`` when there are more than one user matching the given ID.
	 
	 This can happen for instance when a service only supports domain aliases virtually, but the underlying service does not support it. */
	case tooManyUsersFromAPI(users: [any User])
	
	/** Error thrown by ``UserService/logicalUserID(fromUser:)`` when the user ID computation is not possible (missing info from the user for instance). */
	case cannotInferUserIDFromOtherUser
	
	/** Error thrown when a service is asked to do something it does not support. */
	case unsupportedOperation
	
}

typealias Err = OfficeKitError


/* *****************
   MARK: - Utilities
   ***************** */

public extension OfficeKitError {
	
	var isCannotInferUserIDFromOtherUser: Bool {
		switch self {
			case .cannotInferUserIDFromOtherUser: return true
			default:                              return false
		}
	}
	
}
